//
//  ServerRuntime.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import DockerSwiftAPI
import Logging
import RegexBuilder

final actor ServerRuntime: Identifiable {
    typealias Command = String
    
    private let logger: Logger
    
    /// ID of the server
    nonisolated let id: UUID
    /// Path of the server files on disk
    nonisolated let path: URL
    /// Type of Minecraft server
    nonisolated let type: MCServer.ServerType
    /// Version of Minecraft
    private(set) var version: String
    /// Port this server is hosted on
    private(set) var port: UInt16
    /// Minecraft server properties
    var properties: MCServer.Properties
    /// Status of the Minecraft server
    private var status: MCServer.Status = .unknown
    /// Docker process (container) that the server is wrapped in
    internal var process: Docker.Container
    /// This is used to signal when the process needs to be updated on the next start
    private var processNeedsUpdate: Bool = false
    
    init(info: MCServer, rootPath: URL, logger: Logger? = nil) async throws {
        guard let id = info.id else {
            throw MCServerError.invalidServerId
        }
        self.id = id
        self.logger = logger ?? Logger(label: "mcmanager.server.\(id.uuidString)")
        
        // create the local path
        path = rootPath.appendingPathComponent(id.pathSafeString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        
        type = info.type
        version = info.version.description
        port = info.port
        
        // Read the properties
        properties = try MCServer.Properties.read(
            at: path.appendingPathComponent(Defaults.serverPropertiesFileName),
            createDefault: true
        )
        
        // If there is no existing process for thsi server, create one
        if let process = await Defaults.process(for: Defaults.processName(for: id)) {
            self.process = process
        }
        else {
            do {
                // this will automatically pull the image as well
                self.process = try await Docker.create(
                    .init(name: Defaults.processName(for: id)),
                    from: Defaults.dockerImage(for: version),
                    pull: true // pull the image so we have the latest one ready
                )
                // Signal to update the container the next time it's run, since we didn't do a good creating all the properties above
                processNeedsUpdate = true
            }
            catch {
                logger?.critical("Failed to create server \(id.uuidString) due to a docker error: \(error)")
                throw MCServerError.creationError
            }
        }
        
        // Check the current server status (it could have been running through an MCManager restart)
        await updateStatus()
    }
    
    deinit {}
    
    /// A textual representation fo this server runtime
    var description: String {
        "(\(self.id)) \(type.rawValue) \(version)"
    }
    
    // MARK: - Methods
    
    func update(_ info: MCServer) throws {
        guard let id = info.id, self.id == id else {
            throw MCServerError.invalidServerId
        }
        version = info.version.description
        port = info.port
        // Signal that we need to update the process the next time it starts
        processNeedsUpdate = true
    }
    
    /// Delete the server
    func delete() async throws {
        try await ensureIsStopped()
        do {
            // remove the container
            try await Docker.remove(container: process, force: true)
            // delete the files from disk
            try FileManager.default.removeItem(at: path)
        }
        catch {
            throw MCServerError.deletionError(error.localizedDescription)
        }
    }
    
    /// Update the server config (aka: server properties). This also supports partial updates
    func updateProperties(_ newProperties: MCServer.Properties) throws {
        properties.update(with: newProperties)
        do {
            // write the new config to disk
            try properties.write(to: path.appendingPathComponent(Defaults.serverPropertiesFileName))
        }
        catch {
            logger.error("Failed to update server properties: \(error)")
            throw MCServerError.updateFailed(error)
        }
        // Signal that we need to update the process the next time it starts
        processNeedsUpdate = true
    }
    
    nonisolated func listFiles(at relativePath: String? = nil) throws -> [String] {
        let searchPath: URL
        if let relativePath {
            searchPath = path.appendingPathComponent(relativePath)
        }
        else {
            searchPath = path
        }
        
        var files: [String] = []
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: searchPath,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).compactMap {
                if $0.hasDirectoryPath {
                    return "\($0.lastPathComponent)/"
                }
                else {
                    return $0.lastPathComponent
                }
            }
        }
        catch {
            logger.error("Failed to list server files: \(error)")
            throw MCServerError.systemError(error)
        }
        
        // Remove files we don't want to surface
        files.removeAll { Defaults.privateFileNames.contains($0) }
        return files
    }
    
    nonisolated func saveFile(at url: URL, to relativePath: String) async throws {
        if await isRunning {
            throw MCServerError.executionError("Can't add a file to the server while it's running")
        }
        do {
            try FileManager.default.copyItem(
                at: url,
                to: path.appendingPathComponent(relativePath)
            )
        }
        catch {
            logger.error("Failed to save file: \(error)")
            throw MCServerError.systemError(error)
        }
    }
    
    nonisolated func removeFile(at relativePath: String) async throws {
        try await ensureIsStopped()
        do {
            try FileManager.default.removeItem(at: path.appendingPathComponent(relativePath))
        }
        catch {
            logger.error("Failed to delete file: \(error)")
            throw MCServerError.systemError(error)
        }
    }
    
    nonisolated func file(at relativePath: String) -> URL? {
        let fileURL = path.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }
    
    // MARK: - Docker runtime
    
    /// Refresh the process status
    private func updateStatus() async {
        let dockerStatus: Docker.Container.Status
        do {
            dockerStatus = try await Docker.status(of: process)
        }
        catch {
            logger.critical("Failed to fetch container status from docker: \(error)")
            dockerStatus = .unknown
        }
        if case .running = dockerStatus {
            let logs = (try? await logs().reversed()) ?? []
            status = MCServer.Status.latestStatus(in: logs.joined(separator: "\n"))
        }
        else {
            status = MCServer.Status(with: dockerStatus)
        }
    }
    
    /// Check if the process is running
    var isRunning: Bool {
        get async {
            await updateStatus()
            switch status {
            case .starting, .running, .stopping:
                return true
            default:
                return false
            }
        }
    }
    
    private func ensureIsRunning() async throws {
        if !(await isRunning) {
            throw MCServerError.executionError("The server is not running")
        }
    }
    
    private func ensureIsStopped() async throws {
        if await isRunning {
            throw MCServerError.serverIsRunning
        }
    }
    
    /// Configuration for the Docker client with the parameters necessary to run the container
    private var dockerConfig: Docker.ContainerSpec {
        // enviroment variables
        var environment: [Docker.ContainerSpec.EnvironmentVariable] = properties.environmentVariables
        environment.append(contentsOf: [
            .init(key: "EULA", value: "true"), // accept the EULA for the server to start
            .init(key: "ENABLE_QUERY", value: "true"), // Enable query to allow MCManager to perform queries on the server stats
        ])
        
        // ports
        let ports: [Docker.ContainerSpec.PortMapping] = [
            // map both TCP and UDP to the container ports. TCP: game, UDP: queries
            .init(hostPort: UInt(self.port), containerPort: UInt(Defaults.minecraftServerPort), protocol: .tcp),
            .init(hostPort: UInt(self.port), containerPort: UInt(Defaults.minecraftServerPort), protocol: .udp),
        ]
        
        // volumes
        var volumes = [Docker.ContainerSpec.VolumeMapping]()
        for containerPath in Defaults.dockerVolumePaths {
            let pathComponents = containerPath.split(separator: "/", maxSplits: 1)
                .compactMap { String($0) }
            guard pathComponents.count == 2 else { continue }
            let hostPath = path.appendingPathComponent(pathComponents[1], isDirectory: true)
            volumes.append(.init(hostPath: hostPath.path, containerPath: containerPath))
        }

        // container name
        let name = Defaults.processName(for: id)
        
        return .init(
            environment: environment,
            hostname: name,
            interactive: true, // we need this in order to send commands to the server process later
            labels: [
                "mcmanager.server.id": id.uuidString,
                "mcmanager.server.type": type.rawValue,
                "mcmanager.server.version": version,
            ],
            name: name,
            ports: ports,
            restartPolicy: .no,
            volumes: volumes
        )
    }
    
    /// Monitor the server start/stop cycle to accurately report the `status`
    private func waitForStatus(_ desiredStatus: MCServer.Status) async {
        while self.status != desiredStatus {
            let logs = (try? await logs(tail: 100)) ?? []
            let currentStatus = MCServer.Status.latestStatus(in: logs.joined(separator: "\n"))
            if currentStatus != .unknown {
                self.status = currentStatus
            }
            try? await Task.sleep(seconds: 1)
        }
    }
    
    /// Start the server
    func start() async throws {
        try await ensureIsStopped()
        
        // Ensure the server runtime (process) is the most up to date version by checking the internal
        // member processNeedsUpdate and create a new container of necessary
        if processNeedsUpdate {
            do {
                try await Docker.remove(container: process)
                self.process = try await Docker.create(
                    dockerConfig,
                    from: Defaults.dockerImage(for: version),
                    pull: true
                )
            }
            catch {
                status = .error
                logger.critical("Failed to re-create server process: \(error)")
                throw MCServerError.runtimeError(error)
            }
            processNeedsUpdate = false
        }
        
        // update status manually to notify the server is starting
        status = .starting
        do {
            try await Docker.start(process)
        }
        catch {
            status = .error
            logger.critical("Failed to start server: \(error)")
            throw MCServerError.runtimeError(error)
        }
        Task(priority: .background) {
            await waitForStatus(.running)
        }
    }
    
    /// Stop the server
    func stop() async throws {
        try await ensureIsRunning()
        // update status manually to notify the server is stopping
        status = .stopping
        do {
            try await sendCommand("stop")
        }
        catch {
            status = .error
            logger.critical("Failed to send stop command to the server: \(error)")
            throw MCServerError.runtimeError(error)
        }
        Task(priority: .background) {
            await waitForStatus(.stopped)
        }
    }
    
    /// Send a command to the server
    func sendCommand(_ command: Command) async throws {
        try await ensureIsRunning()
        /*
         This is a tricky one, since we can't attach a container and send a command and then detach easily,
         so we resort to executing a few commands in the container:
         1. Get the PID of the server process in the container (since we are using the same minecraft-server image they should all have the same name)
            $ ps axf | grep /minecraft | grep -v grep
            1 root      0:00 {bash} /run/rosetta/rosetta /bin/bash /bin/bash /minecraft/start_server.bash
         2. The first number from the previous output is the PID, we can use that to inject string to the process stdin
            $ echo <minecraft_command> > /proc/<pid>/fd/0
            <minecraft_command_output>
         3. Make sure to wrap every command in (/bin/bash -c "<command>") to ensure we run in a working shell
         */
        let pid = try? await Docker.exec("/bin/bash -c \"ps axf | grep \(Defaults.serverProcessName) | grep -v grep\"", in: process)
            .compactMap { String($0) }
            .split(separator: " ")
            .first
        guard let pid else {
            logger.critical("No process ID found for running server to send command")
            throw MCServerError.failedToSendCommand
        }
        do {
            try await Docker.exec("/bin/bash -c \"echo \(command.sanitized) > /proc/\(pid)/fd/0\"", in: process)
        }
        catch {
            logger.error("Failed to send server command: \(error)")
            throw MCServerError.runtimeError(error)
        }
    }
    
    func logs(tail: UInt? = nil) async throws -> [String] {
        do {
            return try await Docker.logs(for: process, tail: tail)
        }
        catch {
            logger.error("Failed to get server logs: \(error)")
            throw MCServerError.runtimeError(error)
        }
    }
    
    // MARK: - Status
    
    /// Info regarding the current server process
    var info: MCServer.Info {
        get async throws {
            if !(await isRunning) {
                // use this a chance to update the status if the server was stopped for any reason
                status = .stopped
            }
            
            // Query the server for the player count if the server is running
            var playerList = [String]()
            if status == .running {
                // add a fairly quick timeout to the server query as we don't want to block for too long if the server isn't responding
                let query = MCServerQuery(port: self.port, timeout: 1)
                do {
                    playerList = try await query.getPlayers()
                }
                catch {
                    logger.warning("Failed to get player list on server \(id)")
                    // TODO: Throw an error here when the server queries are working
                }
            }
            
            return MCServer.Info(
                status: status,
                needsRestart: processNeedsUpdate,
                onlinePlayers: playerList
            )
        }
    }
    
    /// Metrics for the server process
    var stats: MCServer.Stats {
        get async throws {
            let stats: Docker.Container.Stats
            do {
                stats = try await Docker.stats(of: process)
            }
            catch {
                logger.critical("Failed to fetch server stats from docker: \(error)")
                throw MCServerError.runtimeError(error)
            }
            return MCServer.Stats(cpuPercent: stats.cpuPercent, memoryUsage: stats.memoryUsageBytes)
        }
    }
}

// MARK: - Defaults
extension ServerRuntime {
    enum Defaults {
        
        /// Name for a server process
        static func processName(for serverID: UUID) -> String {
            return "mcmanager_server-\(serverID.pathSafeString)"
        }
        
        /// Docker container process for the given server name
        static func process(for name: String) async -> Docker.Container? {
            try? await Docker.containers.first { $0.name == name }
        }
        
        /// Name of the server docker image
        static func dockerImage(for version: String) -> Docker.Image {
            .init(
                repository: "rdall96",
                name: "minecraft-server",
                tag: .init(version)
            )
        }
        
        /// Name of the server properties file on disk
        static let serverPropertiesFileName = "server-properties.mcmanager"
        
        /// Names of server files that are private to MCManager
        static let privateFileNames: [String] = [
            serverPropertiesFileName,
        ]
        
        /// Docker volume paths to map on the local host
        static let dockerVolumePaths: [String] = [
            "/minecraft/world",
            "/minecraft/configurations",
            "/minecraft/mods"
        ]
        
        /// Default Minecraft server port on the container
        static let minecraftServerPort: UInt16 = 25565
        
        /// Name of the Minecraft server process in the docker container
        static let serverProcessName = "start_server"
        
        /// Name of the Minecraft server image namespace in DockerHub
        static let dockerHubNamespace: DockerHub.Namespace = "rdall96"
        
        /// Name of the Minecraft server image repository in DockerHub
        static let dockerHubRepositoryName: DockerHub.Repository.Name = "minecraft-server"
    }
}

// MARK: - Equatable
extension ServerRuntime: Equatable {
    static func == (lhs: ServerRuntime, rhs: ServerRuntime) -> Bool {
        // same id, means this is the same server
        lhs.id == rhs.id
    }
}

// MARK: - Sanitize commands
extension ServerRuntime.Command {
    fileprivate var sanitized: ServerRuntime.Command {
        self
            .replacingOccurrences(of: "(", with: "\\(") // bash interprets ( and ) as something else (idk)
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "<", with: "\\<")
            .replacingOccurrences(of: ">", with: "\\>")
            .replacingOccurrences(of: "#", with: "\\#") // these won't forward the command to the process stdin because they signal the end of a command in bash
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "*", with: "\\*") // * will list all files in the server directory
            .replacingOccurrences(of: "~", with: "\\~") // ~ will list files under the user path
            .replacingOccurrences(of: "`", with: "") // backticks will straight up break the command
            .replacingOccurrences(of: "$\\(", with: "") // wrapping other text in $() will execute another shell command, we don't have a good way to prevent it, so let's break that fucntionality by removing it
            .replacingOccurrences(of: "\"", with: "\\\("\"")") // double quotes will mess up the command structure, so escape them (this replaces " with \")
            .replacingOccurrences(of: "'", with: "\'") // the same goes for single quotes
    }
}

// MARK: - Status Regex
extension MCServer.Status {
    fileprivate static func latestStatus(in logs: String) -> Self {
        // the order is always the same: starting, running, stopping
        // so checking it backwards and short-circuiting when a regex matches, will give us the latest status
        
        if (try? ServerStatusRegex.stoppingRegex.firstMatch(in: logs)) != nil {
            return .stopping
        }
        
        if (try? ServerStatusRegex.runningRegex.firstMatch(in: logs)) != nil {
            return .running
        }
        
        if (try? ServerStatusRegex.startingRegex.firstMatch(in: logs)) != nil {
            return .starting
        }
        
        return .unknown
    }
}

fileprivate enum ServerStatusRegex {
    // thank you https://swiftregex.com for these awesome builder patterns
    
    // INFO\]:* Starting
    static let startingRegex: Regex<Substring> = {
        Regex {
            "INFO]"
            ZeroOrMore {
                ":"
            }
            " Starting"
        }
        .anchorsMatchLineEndings()
    }()
    
    // INFO\]:* Done \((\d+.\d+)s\)!
    static let runningRegex: Regex<(Substring, Substring)> = {
        Regex {
            "INFO]"
            ZeroOrMore {
                ":"
            }
            " Done ("
            Capture {
                Regex {
                    OneOrMore(.digit)
                    One(".")
                    OneOrMore(.digit)
                }
            }
            "s)!"
        }
        .anchorsMatchLineEndings()
    }()
    
    // INFO\]:* Stopping server
    static let stoppingRegex: Regex<Substring> = {
        Regex {
            "INFO]"
            ZeroOrMore {
                ":"
            }
            " Stopping server"
        }
        .anchorsMatchLineEndings()
    }()
}
