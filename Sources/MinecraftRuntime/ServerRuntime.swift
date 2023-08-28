//
//  ServerRuntime.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
@_spi(MCManager_Runtime) import MCManager_Shared
import DockerSwiftAPI
import Logging
import RegexBuilder

final actor ServerRuntime: Identifiable {
    typealias Command = String
    
    private let logger: Logger
    
    /// ID of the server
    let id: UUID
    /// Path of the server files on disk
    let path: URL
    /// Type of Minecraft server
    let type: Server.ServerType
    /// Version of Minecraft
    private(set) var version: String
    /// Port this server is hosted on
    private(set) var port: UInt16
    /// Configuration of the Minecraft server
    var config: Set<Server.Config>
    /// Status of the Minecraft server
    private var status: Server.Status = .unknown
    /// Docker process (container) that the server is wrapped in
    internal var process: Docker.Container
    /// This is used to signal when the process needs to be updated on the next start
    private var processNeedsUpdate: Bool = false
    
    init(info: Server, rootPath: URL, logger: Logger? = nil) async throws {
        guard let id = info.id else {
            throw MCRError.invalidServerId
        }
        self.id = id
        self.logger = logger ?? Logger(label: "mcmanager.server.\(id.uuidString)")
        
        // create the local path
        path = rootPath.appendingPathComponent(id.pathSafeString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        
        type = info.type
        version = info.version.description
        port = info.port
        
        // Read configuration
        config = try Server.Config.read(
            at: path.appendingPathComponent(Defaults.configFileName),
            createDefault: true
        )
        
        // If there is no existing process for thsi server, create one
        if let process = await Defaults.process(for: Defaults.processName(for: id)) {
            self.process = process
        }
        else {
            // this will automatically pull the image as well
            self.process = try await Docker.create(
                .init(name: Defaults.processName(for: id)),
                from: Defaults.dockerImage(for: version),
                pull: true // pull the image so we have the latest one ready
            )
            // Signal to update the container the next time it's run, since we didn't do a good creating all the properties above
            processNeedsUpdate = true
        }
        
        // Check the current server status (it could have been running through an MCManager restart)
        await updateStatus()
    }
    
    deinit {}
    
    /// A textual representation fo this server runtime
    var description: String {
        "(\(self.id)) \(type.rawValue) \(version)"
    }
    
    // MARK: - Computed Members
    
    private var configPath: URL {
        path.appendingPathComponent(Defaults.configFileName)
    }
    
    private var iconPath: URL {
        path.appendingPathComponent(Defaults.iconFileName)
    }
    
    // MARK: - Methods
    
    func update(_ info: Server) throws {
        guard let id = info.id, self.id == id else {
            throw MCRError.invalidServerId
        }
        version = info.version.description
        port = info.port
        // Signal that we need to update the process the next time it starts
        processNeedsUpdate = true
    }
    
    /// Delete the server
    func delete() async throws {
        guard !(await isRunning) else {
            throw MCRError.deletionError("Can't delete the server while it's running")
        }
        // remove the container
        do {
            try await Docker.remove(container: process, force: true)
        }
        catch {
            throw MCRError.deletionError(error.localizedDescription)
        }
        // delete the files from disk
        do {
            try FileManager.default.removeItem(at: path)
        }
        catch {
            throw MCRError.deletionError(error.localizedDescription)
        }
    }
    
    /// Update the server config (aka: server properties). This also supports partial updates
    func updateConfig(_ newConfig: Set<Server.Config>) throws {
        for item in newConfig {
            // ensure the item exists in the current config
            guard config.firstIndex(where: { $0.id == item.id }) != nil else {
                throw MCRError.invalidServerConfigKey(item.id)
            }
            config.update(with: item)
        }
        // write the new config to disk
        let data = try JSONEncoder().encode(config)
        try data.write(to: configPath)
        // Signal that we need to update the process the next time it starts
        processNeedsUpdate = true
    }
    
    /// Read the serve ricon (if it exists) and return the base64 encoded data
    var icon: Server.Icon {
        .init(atPath: iconPath) ?? .none
    }
    
    /// Update the server icon with the given base64 encoded icon data
    func updateIcon(_ icon: Server.Icon) throws {
        guard let base64 = icon.base64,
              let data = Data(base64Encoded: base64)
        else {
            throw MCRError.invalidIconData
        }
        do {
            try data.write(to: iconPath)
        }
        catch {
            throw MCRError.updateFailed(error)
        }
    }
    
    /// Remove the server icon
    func removeIcon() {
        try? FileManager.default.removeItem(at: iconPath)
    }
    
    // MARK: - Docker runtime
    
    /// Refresh the process status
    private func updateStatus() async {
        let dockerStatus = (try? await Docker.status(of: process)) ?? .unknown
        if dockerStatus == .running {
            let logs = (try? await Docker.logs(for: process)) ?? []
            status = Server.Status.latestStatus(in: logs.joined(separator: "\n"))
        }
        else {
            status = Server.Status(with: dockerStatus)
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
            throw MCRError.executionError("The server is not running")
        }
    }
    
    /// Configuration for the Docker client with the parameters necessary to run the container
    private var dockerConfig: Docker.ContainerSpec {
        // enviroment variables
        var environment: [Docker.ContainerSpec.EnvironmentVariable] = config.map { $0.environmentVariable }
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
    
    /// Ensure the server runtime (process) is the most up to date version by checkign the internal member processNeedsUpdate and create a new container of necessary
    private func recreateProcess() async throws {
        try await Docker.remove(container: process)
        self.process = try await Docker.create(
            dockerConfig,
            from: Defaults.dockerImage(for: version),
            pull: true
        )
        processNeedsUpdate = false
    }
    
    /// Monitor the server start/stop cycle to accurately report the `status`
    private func waitForStatus(_ desiredStatus: Server.Status) async {
        while self.status != desiredStatus {
            let logs = (try? await logs(tail: 100)) ?? []
            let currentStatus = Server.Status.latestStatus(in: logs.joined(separator: "\n"))
            if currentStatus != .unknown {
                self.status = currentStatus
            }
            try? await Task.sleep(seconds: 1)
        }
    }
    
    /// Start the server
    func start() async throws {
        if await isRunning {
            throw MCRError.executionError("The server is already running")
        }
        try await recreateProcess()
        // update status manually to notify the server is starting
        status = .starting
        do {
            try await Docker.start(process)
            Task(priority: .background) { await waitForStatus(.running) }
        }
        catch {
            status = .error
            throw MCRError.dockerError(error)
        }
    }
    
    /// Stop the server
    func stop() async throws {
        try await ensureIsRunning()
        // update status manually to notify the server is stopping
        status = .stopping
        do {
            try await send(command: "stop")
            Task(priority: .background) { await waitForStatus(.stopped) }
        }
        catch {
            status = .error
            throw MCRError.dockerError(error)
        }
    }
    
    /// Restart the server with an optional delay in seconds
    func restart(delay: UInt? = nil) async throws {
        try await ensureIsRunning()
        do {
            if let delay {
                try await send(command: "/say The server will restart in \(delay) second(s)")
                try await Task.sleep(seconds: delay)
            }
            try await stop()
            try await start()
        }
        catch {
            throw MCRError.dockerError(error)
        }
    }
    
    /// Send a command to the server
    func send(command: Command) async throws {
        try await ensureIsRunning()
        /*
         This is a tricky one, since we can't attach a container and send a command and then detach easily,
         so we resort to executing a few commands in the container:
         1. Get the PID of the server process in the container (since we are using the same minecraft-server image they should all have the same name)
            $ top -n 1 | grep start_server.sh
            1     0 root     S     143m   2%   0   0% {start_server.sh} /usr/bin/qemu-x8
         2. The first number from the previous output is the PID, we can use that to inject string to the process stdin
            $ echo <minecraft_command> > /proc/<pid>/fd/0
            <minecraft_command_output>
         3. Make sure to wrap every command in (/bin/bash -c "<command>") to ensure we run in a working shell
         */
        let pid = try await Docker.exec("/bin/bash -c \"top -n 1 | grep \(Defaults.serverProcessName)\"", in: process)
            .split(separator: " ")
            .first
        guard let pid else {
            throw MCRError.failedToSendCommand
        }
        do {
            try await Docker.exec("/bin/bash -c \"echo \(command.sanitized) > /proc/\(pid)/fd/0\"", in: process)
        }
        catch {
            throw MCRError.failedToSendCommand
        }
    }
    
    func logs(tail: UInt? = nil) async throws -> [String] {
        try await Docker.logs(for: process, tail: tail)
    }
    
    // MARK: - Status
    
    /// Info regarding the current server process
    var info: Server.Info {
        get async throws {
            if !(await isRunning) {
                // use this a chance to update the status if the server was stopped for any reason
                status = .stopped
            }
            
            // Query the server for the player count if the server is running
            var playerList = [String]()
            if status == .running {
                // add a fairly quick timeout to the server query as we don't want to block for too long if the server isn't responding
                let query = ServerQuery(port: self.port, timeout: 1)
                do {
                    playerList = try await query.getPlayers()
                }
                catch {
                    logger.warning("Failed to get player list on server \(id)")
                }
            }
            
            // the max player count is stored in the server config
            let maxPlayerCount: UInt
            switch config.first(where: { $0.id == "MAX_PLAYERS" })?.value {
            case .number(let int):
                maxPlayerCount = UInt(int)
            default:
                maxPlayerCount = 0
            }
            
            return .init(
                status: status,
                onlinePlayers: playerList,
                maximumPlayerCount: maxPlayerCount
            )
        }
    }
    
    /// Metrics for the server process
    var metrics: Server.Metrics {
        get async throws {
            let stats = try await Docker.stats(of: process)
            return .init(
                needsRestart: processNeedsUpdate,
                cpuPercent: stats.cpuPercent,
                memoryUsage: stats.memoryUsageBytes
            )
        }
    }
}

// MARK: - Defaults
extension ServerRuntime {
    enum Defaults {
        
        /// Name for a server process
        static func processName(for serverId: UUID) -> String {
            return "mcmanager_server-\(serverId.pathSafeString)"
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
        
        /// Name of the server config file on disk
        static let configFileName = "config.json"
        
        /// Name of the server icon on disk
        static let iconFileName = "icon.png"
        
        /// Name of the server mods directory on disk
        static let modsDirectoryName = "mods"
        
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
extension Server.Status {
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
