//
//  ServerManager.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import DockerSwiftAPI
import Logging

/// Manages Minecraft server runtimes running on the same host.
final class MinecraftServerManager {
    
    private let serversRoot: URL
    private let logger: Logger
    private var serverRuntimes: [UUID : MinecraftServerRuntime]
    
    init(serversRoot: URL, logger: Logger? = nil) throws {
        // create the servers root directory if it doesn't exist
        self.serversRoot = serversRoot
        try FileManager.default.createDirectory(at: serversRoot, withIntermediateDirectories: true)
        self.logger = logger ?? Logger(label: "mcmanager.server-orchestra")
        serverRuntimes = [:]
        
        self.logger.info("Minecraft servers directory: \(serversRoot.path)")
    }
    
    deinit {}
    
    /// Clean up unused files on the system
    func cleanup() async throws {
        // Find any unused servers
        let allServersOnDisk = try FileManager.default.contentsOfDirectory(
            at: serversRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsSubdirectoryDescendants
        )
        let unusedServerIDs: [UUID] = allServersOnDisk.compactMap {
            guard let uuid = UUID(uuidString: $0.lastPathComponent),
                  serverRuntimes[uuid] == nil
            else {
                return nil
            }
            return uuid
        }
        
        // Remove files for the unused servers
        for serverID in unusedServerIDs {
            let serverPath = serversRoot.appendingPathComponent(serverID.uuidString)
            try FileManager.default.removeItem(at: serverPath)
        }
        
        // Remove any containers for the unused servers
        let unusedProcessNames = unusedServerIDs.compactMap {
            MinecraftServerRuntime.Defaults.processName(for: $0)
        }
        let unusedContainers = try await Docker.containers.filter {
            guard let containerName = $0.name else { return false }
            return unusedProcessNames.contains(containerName)
        }
        for unusedContainer in unusedContainers {
            try await Docker.remove(container: unusedContainer, removeVolumes: true, force: true)
        }
    }
    
    // MARK: - Server management
    
    private func requireServer(_ server: MinecraftServer) throws -> UUID {
        guard let uuid = server.id, serverRuntimes[uuid] != nil else {
            throw MinecraftServerError.notFound
        }
        return uuid
    }
    
    private func requireServer(id uuid: UUID) throws -> MinecraftServerRuntime {
        guard let serverRuntime = serverRuntimes[uuid] else {
            throw MinecraftServerError.notFound
        }
        return serverRuntime
    }
    
    /// Add a server.
    /// If it doesn't exist, this methods creates the new server.
    func add(server: MinecraftServer) async throws {
        // ensure this server doesn't already exist
        guard let serverID = server.id else {
            throw MinecraftServerError.invalidID
        }
        guard serverRuntimes[serverID] == nil else {
            logger.error("Attempted to add a server with a duplicate id: \(serverID)")
            throw MinecraftServerError.alreadyExists
        }
        let runtime = try await MinecraftServerRuntime(
            info: server,
            rootPath: serversRoot,
            logger: logger
        )
        serverRuntimes[serverID] = runtime
        let runtimeDescription = await runtime.description
        logger.notice("Added server: \(runtimeDescription)")
    }
    
    /// Update the info for the given server
    func update(server: MinecraftServer) async throws {
        let serverID = try requireServer(server)
        try await serverRuntimes[serverID]?.update(server)
        logger.notice("Updated server \(serverID)")
    }
    
    /// Delete a server by ID
    func deleteServer(id uuid: UUID) async throws {
        _ = try requireServer(id: uuid)
        try await serverRuntimes[uuid]?.delete()
        serverRuntimes.removeValue(forKey: uuid)
        logger.notice("Deleted server \(uuid)")
    }
    
    // MARK: - Runtime support
    
    /// Get information regarding all supported runtimes that can be used to create new servers
    var allSupportedRuntimes: [MinecraftServer.RuntimeSupport] {
        get async throws {
            let allTags: [DockerHub.Tag.Name]
            do {
                allTags = try await DockerHub.tags(
                    for: MinecraftServerRuntime.Defaults.dockerHubRepositoryName,
                    in: MinecraftServerRuntime.Defaults.dockerHubNamespace
                ).compactMap { $0.name }
            }
            catch {
                logger.error("Faield to fetch supported server runtime info: \(error)")
                throw MinecraftServerError.systemError(error)
            }
            return MinecraftServer.ServerType.allCases.compactMap {
                .init(type: $0, versions: MinecraftServer.RuntimeSupport.tags(for: $0, from: allTags))
            }
        }
    }
    
    // MARK: - Status
    
    /// Information regarding the currect server process
    func info(for serverID: UUID) async throws -> MinecraftServer.Info {
        let server = try requireServer(id: serverID)
        return try await server.info
    }
    
    /// Usage metrics for the current server process
    func stats(for serverID: UUID) async throws -> MinecraftServer.Stats {
        let server = try requireServer(id: serverID)
        return try await server.stats
    }
    
    // MARK: - Properties & config
    
    /// Get the server config (aka server properties)
    func properties(for serverID: UUID) async throws -> MinecraftServer.Properties {
        let server = try requireServer(id: serverID)
        return await server.properties
    }
    
    /// Update the server properties
    func updateProperties(_ properties: MinecraftServer.Properties, for serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        try await server.updateProperties(properties)
        logger.info("Updated server properties for \(serverID)")
    }
    
    // MARK: - Execution
    
    var runningServersCount: UInt {
        get async {
            await withTaskGroup(of: Bool.self, returning: UInt.self) { group in
                serverRuntimes.values.forEach { server in
                    group.addTask {
                        let status = await server.dockerProcessStatus
                        return status == .running || status == .restarting || status == .paused
                    }
                }
                var count: UInt = 0
                while let result = await group.next() {
                    count += result ? 1 : 0
                }
                return count
            }
        }
    }
    
    /// Start a server
    func startServer(with serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        if await server.isRunning {
            throw MinecraftServerError.running
        }
        // check if this port is already in use by another running server
        let serverPort = await server.port
        for runtime in serverRuntimes.values {
            if await runtime.isRunning, await runtime.port == serverPort {
                logger.warning("Did not start server \(serverID) because another server is uring the same port \(serverPort)")
                throw MinecraftServerError.portAlreadyInUse
            }
        }
        try await server.start()
        logger.notice("Requested server \(serverID) to start")
    }
    
    /// Stop a server
    func stopServer(with serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        try await server.stop()
        logger.notice("Requested server \(serverID) to stop")
    }
    
    func sendCommand(_ command: String, to serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        try await server.sendCommand(command)
    }
    
    func logs(for serverID: UUID, tail: UInt? = nil) async throws -> [String] {
        let server = try requireServer(id: serverID)
        return try await server.logs(tail: tail)
    }
    
    // MARK: - File management
    
    func downloadServer(with serverID: UUID) async throws -> URL {
        let server = try requireServer(id: serverID)
        if await server.isRunning {
            throw MinecraftServerError.running
        }
        return server.path
    }
    
    func listFiles(at relativePath: String? = nil, for serverID: UUID) async throws -> [String] {
        try requireServer(id: serverID)
            .listFiles(at: relativePath)
    }
    
    func saveFile(at url: URL, for serverID: UUID, to relativePath: String) async throws {
        try await requireServer(id: serverID)
            .saveFile(at: url, to: relativePath)
    }
    
    func removeFile(at relativePath: String, for serverID: UUID) async throws {
        try await requireServer(id: serverID)
            .removeFile(at: relativePath)
    }
    
    func file(at relativePath: String, from serverID: UUID) async throws -> URL? {
        try requireServer(id: serverID)
            .file(at: relativePath)
    }

    // MARK: - Player management

    func operators(for serverID: MinecraftServer.IDValue) async throws -> MinecraftServer.Operators {
        try await requireServer(id: serverID).operators
    }

    func addOperator(_ op: MinecraftServer.Operator, on serverID: MinecraftServer.IDValue) async throws {
        try await requireServer(id: serverID).addOperator(op)
    }

    func removeOperator(_ player: MinecraftPlayerInfo, on serverID: MinecraftServer.IDValue) async throws {
        try await requireServer(id: serverID).removeOperator(player)
    }

    func whitelist(for serverID: MinecraftServer.IDValue) async throws -> MinecraftServer.Whitelist {
        try await requireServer(id: serverID).whitelist
    }

    func whitelistPlayer(_ player: MinecraftPlayerInfo, on serverID: MinecraftServer.IDValue) async throws {
        try await requireServer(id: serverID).whitelistPlayer(player)
    }

    func removeWhitelistedPlayer(_ player: MinecraftPlayerInfo, on serverID: MinecraftServer.IDValue) async throws {
        try await requireServer(id: serverID).removeWhitelistedPlayer(player)
    }

    func bannedPlayers(for serverID: MinecraftServer.IDValue) async throws -> MinecraftServer.BannedPlayers {
        try await requireServer(id: serverID).bannedPlayers
    }

    func banPlayer(_ player: MinecraftPlayerInfo, reason: String? = nil, on serverID: MinecraftServer.IDValue) async throws {
        try await requireServer(id: serverID).banPlayer(player, reason: reason)
    }

    func pardonPlayer(_ player: MinecraftPlayerInfo, on serverID: MinecraftServer.IDValue) async throws {
        try await requireServer(id: serverID).pardonPlayer(player)
    }
}
