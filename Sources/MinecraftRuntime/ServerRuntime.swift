//
//  ServerRuntime.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
@_spi(MCManager_Runtime) import MCManager_Shared
import DockerSwift

final actor ServerRuntime: Identifiable {
    
    let id: UUID
    let path: URL
    let type: Server.ServerType
    private(set) var version: String
    private(set) var port: UInt16
    
    var config: Set<Server.Config>
    
    private let docker: DockerClient
    private var status: Server.Status
    private var process: Container?
    
    init(info: Server, rootPath: URL, docker: DockerClient) async throws {
        guard let id = info.id else {
            throw MCRError.invalidServerId
        }
        self.id = id
        
        // create the local path
        path = rootPath.appendingPathComponent(id.pathSafeString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        
        type = info.type
        version = info.version
        port = info.port
        
        // Read configuration
        config = try Server.Config.read(
            at: path.appendingPathComponent(Self.configFileName),
            createDefault: true
        )
        
        // Set the status (this will be updated later on the first status fetch)
        self.docker = docker
        status = .unknown
        process = try? await docker.containers.get(processName)
        
        // download the docker image for this container
        do {
            _ = try await docker.images.pull(byName: dockerImageName)
        }
        catch {
            throw MCRError.downloadFailed
        }
    }
    
    deinit {}
    
    // MARK: - Computed Members
    
    private var processName: String {
        let serverId = id.pathSafeString
        return "mcmanager_server-\(serverId)"
    }
    
    private var configPath: URL {
        path.appendingPathComponent(Self.configFileName)
    }
    
    private var iconPath: URL {
        path.appendingPathComponent(Self.iconFileName)
    }
    
    private var dockerImageName: String {
        "\(Self.dockerImageName):\(version)"
    }
    
    // MARK: - Methods
    
    func update(_ info: Server) throws {
        guard let id = info.id, self.id == id else {
            throw MCRError.invalidServerId
        }
        version = info.version
        port = info.port
    }
    
    /// Delete the server
    func delete() async throws {
        await updateStatus()
        // remove the container
        do {
            try await docker.containers.remove(
                process?.id ?? processName,
                force: true
            )
        }
        catch {
            // if the container was never created, than don't throw
            if process != nil {
                throw MCRError.deletionError(error.localizedDescription)
            }
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
    }
    
    /// Read the serve ricon (if it exists) and return the base64 encoded data
    var icon: String? {
        guard FileManager.default.fileExists(atPath: iconPath.path),
              let contents = try? Data(contentsOf: iconPath)
        else {
            return nil
        }
        return contents.base64EncodedString()
    }
    
    /// Update the server icon with the given base64 encoded icon data
    func updateIcon(_ base64: String) throws {
        guard let data = Data(base64Encoded: base64) else {
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
        process = try? await docker.containers.get(process?.id ?? processName)
    }
    
    /// Check if the process is running
    private var isRunning: Bool {
        get async {
            await updateStatus()
            guard let process else { return false }
            return !Self.dockerStoppedStatuses.contains(process.state.status)
        }
    }
    
    /// Configuration for the Docker client with the parameters necessary to run the container
    private var dockerConfig: ContainerSpec {
        // enviroment variables
        var env = config.map { $0.environmentVariable }
        env.append("EULA=true")
        
        // volumes
        let volumes: [String : ContainerConfig.EmptyObject] = [:]
        
        return .init(
            config: .init(
                image: dockerImageName,
                environmentVars: env,
                exposedPorts: [
                    .tcp(Self.minecraftServerPort),
                    .udp(Self.minecraftServerPort)
                ],
                volumes: volumes
            ),
            hostConfig: .init(
                portBindings: [ // expose server on the host
                    .tcp(Self.minecraftServerPort) : [.publishTo(hostIp: "0.0.0.0", hostPort: UInt16(port))],
                    .udp(Self.minecraftServerPort) : [.publishTo(hostIp: "0.0.0.0", hostPort: UInt16(port))]
                ]
            )
        )
    }
    
    /// Start the server
    func start() async throws {
        guard !(await isRunning) else {
            throw MCRError.executionError("The server is already running")
        }
        status = .starting
        do {
            // create a new container for this runtime
            let process = try await docker.containers.create(
                name: processName,
                spec: dockerConfig
            )
            try await docker.containers.start(process.id)
            status = .running
            self.process = process
        }
        catch {
            status = .error
            throw MCRError.dockerError(error)
        }
    }
    
    /// Stop the server
    func stop() async throws {
        guard await isRunning, let process else {
            throw MCRError.executionError("The server is not running")
        }
        status = .stopping
        do {
            try await docker.containers.stop(process.id)
            status = .stopped
            // delete the container (this will be re-created the next time the server starts
            try await docker.containers.remove(process.id)
            self.process = nil
        }
        catch {
            status = .error
            throw MCRError.dockerError(error)
        }
    }
    
    /// Restart the server with an optional delay in seconds
    func restart(delay: UInt32? = nil) async throws {
        guard await isRunning else {
            throw MCRError.executionError("The server is not running")
        }
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
    
    /// Send a commadn to the server
    func send(command: String) async throws {
        guard await isRunning, let process else {
            throw MCRError.executionError("The server is not running")
        }
        do {
            let terminal = try await docker.containers.attach(container: process, stream: false, logs: false)
            try await terminal.send(command)
        }
        catch {
            throw MCRError.dockerError(error)
        }
    }
    
    func logs(tail: UInt? = nil) async throws -> String {
        guard await isRunning, let process else {
            throw MCRError.executionError("The server is not running")
        }
        return "Not implemented"
//        do {
//            for try await log in try await Self.docker.containers.logs(container: process, tail: tail) {
//                return log.message
//            }
//        }
//        catch {
//            throw MCRError.dockerError(error)
//        }
    }
    
    // MARK: - Info
    
    private var stats: ContainerStats? {
        get async {
            guard await isRunning, let process else {
                return nil
            }
            return try? await docker.containers.stats(process.id).first(where: { _ in true })
        }
    }
    
    /// Get the CPU usage of the server process
    private var cpuUsage: UInt64 {
        get async {
            await stats?.cpu.systemCpuUsage ?? 0
        }
    }
    
    /// Memory usage in bytes of the server process
    private var memoryUsageBytes: UInt64 {
        get async {
            await stats?.memory.usage ?? 0
        }
    }
    
    /// Info regarding the current server process
    var info: Server.Info {
        get async {
            if !(await isRunning) {
                // use this a chance to update the status if the server was stopped for any reason so we don't risk reporting an active status with nil stats
                status = .stopped
            }
            return .init(
                status: status,
                onlinePlayerCount: 0,
                cpuUsage: await cpuUsage,
                memoryUsage: await memoryUsageBytes
            )
        }
    }
}

// MARK: - Defaults
extension ServerRuntime {
    
    /// Name of the server config file on disk
    static var configFileName: String { "config.json" }
    
    /// Name of the server icon on disk
    static var iconFileName: String { "icon.png" }
    
    /// Name of the server mods directory on disk
    static var modsDirectoryName: String { "mods" }
    
    /// Name of the server docker image
    static var dockerImageName: String { "rdall96/minecraft-server" }
    
    /// Docker volume paths to map on the local host
    static var dockerVolumePaths: [String] {
        [
            "/minecraft/world",
            "/minecraft/mods"
        ]
    }
    
    /// Default Minecraft server port on the container
    static var minecraftServerPort: UInt16 { 25565 }
    
    /// Docker container status for when the process is stopped
    static var dockerStoppedStatuses: [Container.State.State] {
        [.dead, .exited, .paused, .removing]
    }
}

// MARK: - Equatable
extension ServerRuntime: Equatable {
    static func == (lhs: ServerRuntime, rhs: ServerRuntime) -> Bool {
        // same id, means this is the same server
        lhs.id == rhs.id
        
    }
}
