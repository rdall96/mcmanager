//
//  Orchestra.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import DockerSwiftAPI
import Logging

/**
 The orchestra is an object that manages all the server runtimes on the current host
 */
final class MCServerOrchestra {
    
    private let serversRoot: URL
    private let logger: Logger
    private var serverRuntimes: [UUID : ServerRuntime]
    
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
        // prunes unused docker images
        do {
            try await Docker.systemPrune()
        }
        catch {
            throw MCServerError.dockerError(error)
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
    
    private func requireServer(_ server: MCServer) throws -> UUID {
        guard let uuid = server.id,
              serverRuntimes[uuid] != nil
        else {
            logger.error("Missing server with id \"\(server.id?.uuidString ?? "unknown")\"!")
            throw MCServerError.invalidServerId
        }
        return uuid
    }
    
    private func requireServer(id uuid: UUID) throws -> ServerRuntime {
        guard let serverRuntime = serverRuntimes[uuid] else {
            logger.error("Server with id \"\(uuid.uuidString)\" not found!")
            throw MCServerError.invalidServerId
        }
        return serverRuntime
    }
    
    /// Add a server to the orchestra, if it doesn't exist, this methods creates the new server
    func add(server: MCServer) async throws {
        // ensure this server doesn't already exist
        guard let serverID = server.id else {
            logger.error("Missing id for server \"\(server.name)\"!")
            throw MCServerError.invalidServerId
        }
        guard serverRuntimes[serverID] == nil else {
            logger.error("Attempted to add a duplicate server with id \"\(serverID)\"")
            throw MCServerError.duplicateServer(serverID)
        }
        let runtime = try await ServerRuntime(
            info: server,
            rootPath: serversRoot,
            logger: logger
        )
        serverRuntimes[serverID] = runtime
        let runtimeDescription = await runtime.description
        logger.info("Added server: \(runtimeDescription)")
    }
    
    /// Update the info for the given server
    func update(server: MCServer) async throws {
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
    var allSupportedRuntimes: [MCServer.RuntimeSupport] {
        get async throws {
            logger.info("Fetching supported runtimes")
            let allTags = try await DockerHub.tags(
                for: ServerRuntime.Defaults.dockerHubRepositoryName,
                in: ServerRuntime.Defaults.dockerHubNamespace
            ).compactMap { $0.name }
            logger.info("Found \(allTags.count) tag(s) on DockerHub")
            return MCServer.ServerType.allCases.compactMap {
                .init(type: $0, versions: MCServer.RuntimeSupport.tags(for: $0, from: allTags))
            }
        }
    }
    
    // MARK: - Status
    
    /// Information regarding the currect server process
    func info(for serverID: UUID) async throws -> MCServer.Info {
        let server = try requireServer(id: serverID)
        logger.info("Getting game info for server \(serverID)")
        return try await server.info
    }
    
    /// Usage metrics for the current server process
    func metrics(for serverID: UUID) async throws -> MCServer.Metrics {
        let server = try requireServer(id: serverID)
        logger.info("Getting runtime metrics for server \(serverID)")
        return try await server.metrics
    }
    
    // MARK: - Properties & config
    
    /// Get the server config (aka server properties)
    func properties(for serverID: UUID) async throws -> MCServer.Properties {
        let server = try requireServer(id: serverID)
        logger.info("Getting runtime configuration for server \(serverID)")
        return await server.properties
    }
    
    /// Update the server properties
    func updateProperties(_ properties: MCServer.Properties, for serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        try await server.updateProperties(properties)
        logger.info("Updated \(properties.count) server properties for \(serverID)")
    }
    
    /// Get the icon for a server
    func icon(for serverID: UUID) async throws -> MCServer.Icon? {
        let server = try requireServer(id: serverID)
        logger.info("Requesting server icon for \(serverID)")
        return await server.icon
    }
    
    /// Update the server icon
    func updateIcon(_ icon: MCServer.Icon, for serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        try await server.updateIcon(icon)
        logger.info("Updated server icon for \(serverID)")
    }
    
    /// Remove the server icon
    func removeIcon(for serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        await server.removeIcon()
        logger.info("Deleted custom server icon for \(serverID)")
    }
    
    // MARK: - Execution
    
    /// Start a server
    func startServer(with serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        logger.info("Starting server \(serverID)")
        // ensure the server isn't already running
        if await server.isRunning {
            logger.warning("Did not start server \(serverID). Reason: it was already running")
            throw MCServerError.executionError("This server is already running")
        }
        // check if this port is already in use by another running server
        let serverPort = await server.port
        for runtime in serverRuntimes.values {
            if await runtime.isRunning, await runtime.port == serverPort {
                logger.warning("Did not start server \(serverID). Reason: server port \(serverPort) is already in use")
                throw MCServerError.executionError("This port is already in use by another server")
            }
        }
        try await server.start()
        logger.notice("Requested server \(serverID) to start")
    }
    
    /// Stop a server
    func stopServer(with serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        logger.info("Stopping server \(serverID)")
        try await server.stop()
        logger.notice("Requested server \(serverID) to stop")
    }
    
    func sendCommand(_ command: String, to serverID: UUID) async throws {
        let server = try requireServer(id: serverID)
        logger.info("Sending command to server \(serverID)")
        try await server.sendCommand(command)
        logger.notice("Sent command to \(serverID): \(command)")
    }
    
    func logs(for serverID: UUID, tail: UInt? = nil) async throws -> [String] {
        let server = try requireServer(id: serverID)
        logger.info("Requesting logs for server \(serverID)")
        return try await server.logs(tail: tail)
    }
}
