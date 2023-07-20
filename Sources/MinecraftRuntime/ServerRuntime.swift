//
//  ServerRuntime.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
@_spi(MCManager_Runtime) import MCManager_Shared
import DockerSwiftAPI

final actor ServerRuntime: Identifiable {
    
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
    
    init(info: Server, rootPath: URL) async throws {
        guard let id = info.id else {
            throw MCRError.invalidServerId
        }
        self.id = id
        
        // create the local path
        path = rootPath.appendingPathComponent(id.pathSafeString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        
        type = info.type
        version = info.version.description
        port = info.port
        
        // Read configuration
        config = try Server.Config.read(
            at: path.appendingPathComponent(Self.configFileName),
            createDefault: true
        )
        
        // If there is no existing process for thsi server, create one
        if let process = await Self.process(for: Self.processName(for: id)) {
            self.process = process
        }
        else {
            // this will automatically pull the image as well
            self.process = try await Docker.create(
                .init(name: Self.processName(for: id)),
                from: Self.dockerImage(version: version)
            )
            // Signal to update the container the next time it's run, since we didn't do a good job above
            processNeedsUpdate = true
        }
        
        // Check the current server status (it could have been running through an MCManager restart)
        await updateStatus()
    }
    
    deinit {}
    
    // MARK: - Computed Members
    
    private var configPath: URL {
        path.appendingPathComponent(Self.configFileName)
    }
    
    private var iconPath: URL {
        path.appendingPathComponent(Self.iconFileName)
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
        guard FileManager.default.fileExists(atPath: iconPath.path),
              let contents = try? Data(contentsOf: iconPath)
        else {
            return .none
        }
        return .init(contents.base64EncodedString())
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
        status = Server.Status(with: dockerStatus)
    }
    
    /// Check if the process is running
    private var isRunning: Bool {
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
        var environment = config.map { $0.environmentVariable }
        environment.append("EULA=true")
        
        // volumes
        var volumes = [String : String]()
        for containerPath in Self.dockerVolumePaths {
            let pathComponents = containerPath.split(separator: "/", maxSplits: 1)
                .compactMap { String($0) }
            guard pathComponents.count == 2 else { continue }
            let hostPath = path.appendingPathComponent(pathComponents[1], isDirectory: true)
            volumes[hostPath.path] = containerPath
        }

        // container name
        let name = Self.processName(for: id)
        
        return .init(
            environment: environment,
            hostname: name,
            name: name,
            ports: [UInt(port):UInt(Self.minecraftServerPort)],
            restartPolicy: .unlessStopped,
            volumes: volumes
        )
    }
    
    /// Ensure the server runtime (process) is the most up to date version by checkign the internal member processNeedsUpdate and create a new container of necessary
    private func ensureRuntimeIsUpdated() async throws {
        // If the process needs to be updated, create a new container
        if processNeedsUpdate {
            // remove the previous container
            try await Docker.remove(container: process)
            // create a new container using the current server runtime specs
            self.process = try await Docker.create(
                dockerConfig,
                from: Self.dockerImage(version: version)
            )
            processNeedsUpdate = false
        }
    }
    
    /// Start the server
    func start() async throws {
        if await isRunning {
            throw MCRError.executionError("The server is already running")
        }
        try await ensureRuntimeIsUpdated()
        // update status manually to notify the server is starting
        status = .starting
        do {
            try await Docker.start(process)
            // TODO: Monitor startup so we can keep the status as `starting` as long as the server isn't ready, then sync with Docker
            // update the status again to ensure we stay in sync with docker
            await updateStatus()
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
            try await Docker.stop(process)
            // TODO: Monitor shutdown so we can keep the status as `stopping` as long as the server isn't ready, then sync with Docker
            // update the status again to ensure we stay in sync with docker
            await updateStatus()
        }
        catch {
            status = .error
            throw MCRError.dockerError(error)
        }
    }
    
    /// Restart the server with an optional delay in seconds
    func restart(delay: UInt32? = nil) async throws {
        try await ensureIsRunning()
        do {
            if let delay {
                try await send(command: "/say The server will restart in \(delay.description) second(s)")
                let sleepTime: UInt64 = UInt64(delay * 1000 * 1000)
                try await Task.sleep(nanoseconds: sleepTime)
            }
            try await stop()
            try await start()
        }
        catch {
            throw MCRError.dockerError(error)
        }
    }
    
    /// Send a command to the server and get the result for it
    @discardableResult
    func send(command: String) async throws -> String {
        try await ensureIsRunning()
        /*
         This is a tricky one, since we can't attach a container and sned a command and then detach easily,
         so we resort to executing a few commands in the container:
         1. Get the PID of the server process in the container (since we are using the same minecraft-server image they should all have the same name)
            > top -n 1 | grep start_server.sh
            1     0 root     S     143m   2%   0   0% {start_server.sh} /usr/bin/qemu-x8
         2. The first number from the previous output is the PID, we can use that to inject string to the process stdin
            > echo <minecraft_command> | /proc/<pid>/fd/0
            <minecraft_command_output>
         3. Make sure to wrap every command in (/bin/bash -c "<command>") to ensure we run in a working shell
         */
        let pid = try await Docker.exec("/bin/bash -c \"top -n 1 | grep \(Self.serverProcessName)\"", in: process)
            .split(separator: " ")
            .first
        guard let pid else {
            throw MCRError.failedToSendCommand
        }
        do {
            return try await Docker.exec("/bin/bash -c \"echo \(command) | /proc/\(pid)/fd/0\"", in: process)
        }
        catch {
            throw MCRError.failedToSendCommand
        }
    }
    
    func logs(tail: UInt? = nil) async throws -> [String] {
        try await Docker.logs(for: process, tail: tail)
    }
    
    // MARK: - Info
    
    /// Info regarding the current server process
    var info: Server.Info {
        get async throws {
            if !(await isRunning) {
                // use this a chance to update the status if the server was stopped for any reason so we don't risk reporting an active status with nil stats
                status = .stopped
            }
            let stats = try await Docker.stats(of: process)
            return .init(
                status: status,
                onlinePlayerCount: 0,
                cpuPercent: stats.cpuPercent,
                memoryUsage: stats.memoryUsageBytes
            )
        }
    }
}

// MARK: - Defaults
extension ServerRuntime {
    
    /// Name for a server process
    static func processName(for serverId: UUID) -> String {
        return "mcmanager_server-\(serverId.pathSafeString)"
    }
    
    /// Name of the server config file on disk
    static var configFileName: String { "config.json" }
    
    /// Name of the server icon on disk
    static var iconFileName: String { "icon.png" }
    
    /// Name of the server mods directory on disk
    static var modsDirectoryName: String { "mods" }
    
    /// Docker container process for the given server name
    static func process(for name: String) async -> Docker.Container? {
        try? await Docker.containers.first {
            $0.name == name
        }
    }
    
    /// Name of the Minecraft server image namespace in DockerHub
    static var dockerHubNamespace: DockerHub.Namespace { "rdall96" }
    
    /// Name of the Minecraft server image repository in DockerHub
    static var dockerHubRepositoryName: DockerHub.Repository.Name { "minecraft-server" }
    
    /// Name of the server docker image
    static func dockerImage(version: String) -> Docker.Image {
        .init(
            repository: Self.dockerHubNamespace,
            name: Self.dockerHubRepositoryName,
            tag: .init(version)
        )
    }
    
    /// Docker volume paths to map on the local host
    static var dockerVolumePaths: [String] {
        [
            "/minecraft/world",
            "/minecraft/mods"
        ]
    }
    
    /// Default Minecraft server port on the container
    static var minecraftServerPort: UInt16 { 25565 }
    
    /// Name of the Minecraft server process in the docker container
    static var serverProcessName: String { "start_server.sh" }
}

// MARK: - Equatable
extension ServerRuntime: Equatable {
    static func == (lhs: ServerRuntime, rhs: ServerRuntime) -> Bool {
        // same id, means this is the same server
        lhs.id == rhs.id
    }
}
