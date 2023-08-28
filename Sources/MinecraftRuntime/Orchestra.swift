//
//  Orchestra.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
@_spi(MCManager_Runtime) import MCManager_Shared
import DockerSwiftAPI
import Logging

/**
 The orchestra is an object that manages all the server runtimes on the current host
 */
public final class ServerOrchestra {
    
    private let serversRoot: URL
    private let logger: Logger
    private var serverRuntimes: [UUID : ServerRuntime]
    
    public init(serversRoot: URL, logger: Logger? = nil) throws {
        // create the servers root directory if it doesn't exist
        self.serversRoot = serversRoot
        try FileManager.default.createDirectory(at: serversRoot, withIntermediateDirectories: true)
        self.logger = logger ?? Logger(label: "mcmanager.server-orchestra")
        serverRuntimes = [:]
        
        self.logger.notice("Minecraft servers directory: \(serversRoot.path)")
    }
    
    deinit {}
    
    /// Clean up unused files on the system
    public func cleanup() async throws {
        // prunes unused docker images
        do {
            try await Docker.systemPrune()
        }
        catch {
            throw MCRError.dockerError(error)
        }
        // remove the files for unused servers
        let allServersOnDisk = try FileManager.default.contentsOfDirectory(
            at: serversRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsSubdirectoryDescendants
        )
        let unusedServersOnDisk: [URL] = allServersOnDisk.filter {
            guard let uuid = UUID(uuidString: $0.lastPathComponent) else { return false }
            return serverRuntimes[uuid] == nil
        }
        for unusedServerPath in unusedServersOnDisk {
            try FileManager.default.removeItem(at: unusedServerPath)
        }
    }
    
    // MARK: - Server management
    
    private func requireServer(_ server: Server) throws -> UUID {
        guard let uuid = server.id,
              serverRuntimes[uuid] != nil
        else {
            logger.error("Missing server with id \"\(server.id?.uuidString ?? "unknown")\"!")
            throw MCRError.invalidServerId
        }
        return uuid
    }
    
    private func requireServer(withId uuid: UUID) throws -> ServerRuntime {
        guard let serverRuntime = serverRuntimes[uuid] else {
            logger.error("Server with id \"\(uuid.uuidString)\" not found!")
            throw MCRError.invalidServerId
        }
        return serverRuntime
    }
    
    /// Add a server to the orchestra, if it doesn't exist, this methods creates the new server
    public func add(server: Server) async throws {
        // ensure this server doesn't already exist
        guard let serverId = server.id else {
            logger.error("Missing id for server \"\(server.name)\"!")
            throw MCRError.invalidServerId
        }
        guard serverRuntimes[serverId] == nil else {
            logger.error("Attempted to add a duplicate server with id \"\(serverId)\"")
            throw MCRError.duplicateServer(serverId)
        }
        let runtime = try await ServerRuntime(
            info: server,
            rootPath: serversRoot,
            logger: logger
        )
        serverRuntimes[serverId] = runtime
        let runtimeDescription = await runtime.description
        logger.info("Added server: \(runtimeDescription)")
    }
    
    /// Update the info for the given server
    public func update(server: Server) async throws {
        let serverId = try requireServer(server)
        try await serverRuntimes[serverId]?.update(server)
        logger.notice("Updated server \(serverId)")
    }
    
    /// Delete a server by ID
    public func delete(serverWithId uuid: UUID) async throws {
        _ = try requireServer(withId: uuid)
        try await serverRuntimes[uuid]?.delete()
        serverRuntimes.removeValue(forKey: uuid)
        logger.notice("Deleted server \(uuid)")
    }
    
    // MARK: - Runtime support
    
    /// Get information regarding all supported runtimes that can be used to create new servers
    public var allSupportedRuntimes: [Server.RuntimeSupport] {
        get async throws {
            logger.info("Fetching supported runtimes")
            let allTags = try await DockerHub.tags(
                for: ServerRuntime.Defaults.dockerHubRepositoryName,
                in: ServerRuntime.Defaults.dockerHubNamespace
            ).compactMap { $0.name }
            logger.info("Found \(allTags.count) tag(s) on DockerHub")
            return Server.ServerType.allCases.compactMap {
                .init(type: $0, versions: Server.RuntimeSupport.tags(for: $0, from: allTags))
            }
        }
    }
    
    // MARK: - Status
    
    /// Information regarding the currect server process
    public func info(for serverId: UUID) async throws -> Server.Info {
        let server = try requireServer(withId: serverId)
        logger.info("Getting game info for server \(serverId)")
        return try await server.info
    }
    
    /// Usage metrics for the current server process
    public func metrics(for serverId: UUID) async throws -> Server.Metrics {
        let server = try requireServer(withId: serverId)
        logger.info("Getting runtime metrics for server \(serverId)")
        return try await server.metrics
    }
    
    // MARK: - Properties & config
    
    /// Get the server config (aka server properties)
    public func config(for serverId: UUID) async throws -> Set<Server.Config> {
        let server = try requireServer(withId: serverId)
        logger.info("Getting runtime configuration for server \(serverId)")
        return await server.config
    }
    
    /// Update the config for a server
    public func updateConfig(_ config: Set<Server.Config>, for serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.updateConfig(config)
        logger.info("Updated \(config.count) configuration(s) for server runtime \(serverId)")
    }
    
    /// Get the icon for a server
    public func icon(for serverId: UUID) async throws -> Server.Icon {
        let server = try requireServer(withId: serverId)
        logger.info("Requesting server icon for \(serverId)")
        return await server.icon
    }
    
    /// Update the server icon
    public func updateIcon(_ icon: Server.Icon, for serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.updateIcon(icon)
        logger.info("Updated server icon for \(serverId)")
    }
    
    /// Remove the server icon
    public func removeIcon(for serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        await server.removeIcon()
        logger.info("Deleted custom server icon for \(serverId)")
    }
    
    // MARK: - Execution
    
    /// Start a server
    public func start(serverWithId serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        logger.info("Starting server \(serverId)")
        // ensure the server isn't already running
        if await server.isRunning {
            logger.warning("Did not start server \(serverId). Reason: it was already running")
            throw MCRError.executionError("This server is already running")
        }
        // check if this port is already in use by another running server
        let serverPort = await server.port
        for runtime in serverRuntimes.values {
            if await runtime.isRunning, await runtime.port == serverPort {
                logger.warning("Did not start server \(serverId). Reason: server port \(serverPort) is already in use")
                throw MCRError.executionError("This port is already in use by another server")
            }
        }
        try await server.start()
        logger.notice("Requested server \(serverId) to start")
    }
    
    /// Stop a server
    public func stop(serverWithId serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        logger.info("Stopping server \(serverId)")
        try await server.stop()
        logger.notice("Requested server \(serverId) to stop")
    }
    
    /// Restart a server
    public func restart(serverWithId serverId: UUID, delay: UInt? = nil) async throws {
        let server = try requireServer(withId: serverId)
        logger.info("Restarting server \(serverId)")
        try await server.restart(delay: delay)
        logger.notice("Requested server \(serverId) to restart")
    }
    
    public func send(command: String, to serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        logger.info("Sending command to server \(serverId)")
        try await server.send(command: command)
        logger.notice("Sent command to \(serverId): \(command)")
    }
    
    public func logs(for serverId: UUID, tail: UInt? = nil) async throws -> [String] {
        let server = try requireServer(withId: serverId)
        logger.info("Requesting logs for server \(serverId)")
        return try await server.logs(tail: tail)
    }
}
