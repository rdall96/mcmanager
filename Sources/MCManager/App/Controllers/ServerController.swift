//
//  ServerController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor

struct ServerController: MCManagerAPIRoute, RouteCollection {
    
    let logger: Logger
    let manager: MCServerManager
    
    init(serversPath: URL, database: any Database, logger: Logger) async throws {
        self.manager = try .init(serversRoot: serversPath, logger: logger)
        self.logger = logger
        
        try await loadExistingServers(from: database)
    }
    
    func boot(routes: RoutesBuilder) throws {
        // V1 APIs
        let servers = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("servers")
        
        // runtime support
        servers.get("support", use: support)
        // default properties
        servers.get("properties", use: defaultProperties)
        // list servers
        servers.get(use: all)
        // create server
        servers.post(use: create)
        // server operations
        servers.group(":serverID") { server in
            server.get(use: self.server(req:))
            server.put(use: update)
            server.delete(use: delete)
            
            // status
            server.get("info", use: info)
            server.get("stats", use: stats)
            
            // properties & config
            server.get("properties", use: properties)
            server.put("properties", use: updateProperties)
            
            // execution
            server.get("start", use: start)
            server.get("stop", use: stop)
            server.post("command", use: command)
            server.get("logs", use: logs)
            
            // files
            server.get("download", use: download)
            server.group("files") { files in
                files.get("browse", use: browseFiles)
                files.get(use: downloadFile)
                files.on(.POST, body: .stream, use: uploadFile)
                files.delete(use: removeFile)
            }
        }
    }
    
    // MARK: - Server management
    
    func all(req: Request) async throws -> [MCServer] {
        var filters = [DatabaseQuery.Filter]()
        
        // server type filter
        if let serverType = req.query[MCServer.ServerType.self, at: "type"] {
            filters.append(.value(
                .path([MCServer.FieldKeys.type.rawValue], schema: MCServer.schema),
                .equal,
                .enumCase(serverType.rawValue)
            ))
        }
        
        var query = MCServer.query(on: req.db)
        for filter in filters {
            query = query.filter(filter)
        }
        return try await query.all()
    }
    
    func create(req: Request) async throws -> MCServer {
        guard try await req.userHasPermissions(for: .createServers) else {
            throw Abort(.unauthorized)
        }
        let server = try req.content.decode(MCServer.self)
        try await ensureIsValid(server: server, on: req.db)
        try await server.save(on: req.db)
        do {
            try await manager.add(server: server)
        }
        catch {
            logger.critical("Failed to create server: \(error)")
            try await server.delete(on: req.db)
            throw error
        }
        return server
    }
    
    func server(req: Request) async throws -> MCServer {
        try await req.server
    }
    
    func update(req: Request) async throws -> MCServer {
        guard try await req.userHasPermissions(for: .editServers) else {
            throw Abort(.unauthorized)
        }
        let serverRequest = try req.content.decode(MCServer.self)
        let server = try await req.server
        
        if !serverRequest.name.isEmpty {
            server.name = serverRequest.name
        }
        if serverRequest.version != .none {
            server.version = serverRequest.version
        }
        if serverRequest.port > 0, serverRequest.port != server.port {
            server.port = serverRequest.port
        }
        server.updatedAt = .now
        
        try await ensureIsValid(server: server, on: req.db)
        try await server.save(on: req.db)
        try await manager.update(server: server)
        return server
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .deleteServers) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        let server = try await req.server
        
        try await server.delete(on: req.db)
        do {
            try await manager.deleteServer(id: serverID)
        }
        catch {
            logger.critical("Failed to delete server from disk, attempting to restore it")
            try await server.restore(on: req.db)
            throw error
        }
        try? await ServerStatusCache.find(serverID, on: req.db)?
            .delete(on: req.db)
        return .noContent
    }
    
    // MARK: - Runtime support
    
    func support(req: Request) async throws -> [MCServer.RuntimeSupport] {
        guard try await req.userHasPermissions(for: .createServers) else {
            throw Abort(.unauthorized)
        }
        return try await manager.allSupportedRuntimes
    }
    
    // MARK: - Status
    
    private func serverStatus(for serverID: UUID, on database: Database) async throws -> ServerStatusCache? {
        let settings = try await self.settings(on: database)
        guard settings.serverStatusCacheIsEnabled else {
            return nil
        }
        let cachedStatus = try await ServerStatusCache.find(serverID, on: database)
        if let cachedStatus, !cachedStatus.isExpired {
            return cachedStatus
        }
        else {
            // delete any previous cached status
            try await cachedStatus?.delete(on: database)
            // create a new cache
            let status = ServerStatusCache(
                id: serverID,
                ttl: settings.serverStatusCacheTTLSeconds,
                info: try await manager.info(for: serverID),
                stats: try await manager.stats(for: serverID)
            )
            try await status.save(on: database)
            return status
        }
    }
    
    func info(req: Request) async throws -> MCServer.Info {
        let serverID = try req.serverID
        guard let info = try await serverStatus(for: serverID, on: req.db)?.info else {
            return try await manager.info(for: serverID)
        }
        return info
    }
    
    func stats(req: Request) async throws -> MCServer.Stats {
        let serverID = try req.serverID
        guard let metrics = try await serverStatus(for: serverID, on: req.db)?.stats else {
            return try await manager.stats(for: serverID)
        }
        return metrics
    }
    
    // MARK: - Properties & config
    
    func defaultProperties(req: Request) async throws -> MCServer.Properties {
        guard try await req.userHasPermissions(for: .readServerProperties) else {
            throw Abort(.unauthorized)
        }
        return MCServer.Properties.defaults
    }
    
    func properties(req: Request) async throws -> MCServer.Properties {
        guard try await req.userHasPermissions(for: .readServerProperties) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        return try await manager.properties(for: serverID)
    }
    
    func updateProperties(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .editServerProperties) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        let properties = try req.content.decode(MCServer.Properties.self)
        try await manager.updateProperties(properties, for: serverID)
        return .ok
    }
    
    // MARK: - Execution
    
    func start(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .startStopServers) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        let settings = try await settings(on: req.db)
        guard await manager.runningServersCount < settings.maxRunningServers else {
            throw Abort(.serviceUnavailable, reason: "Reached maximum number of running servers")
        }
        try await manager.startServer(with: serverID)
        // invalidate the status cache
        try await ServerStatusCache.find(serverID, on: req.db)?.delete(on: req.db)
        return .ok
    }
    
    func stop(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .startStopServers) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        try await manager.stopServer(with: serverID)
        // invalidate the status cache
        try await ServerStatusCache.find(serverID, on: req.db)?.delete(on: req.db)
        return .ok
    }
    
    func command(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .sendServerCommands) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        guard let command = try? req.content.decode(String.self) else {
            throw Abort(.badRequest, reason: "Missing command in request body")
        }
        try await manager.sendCommand(command, to: serverID)
        return .ok
    }
    
    func logs(req: Request) async throws -> [String] {
        guard try await req.userHasPermissions(for: .readServerLogs) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        var tail: UInt? = nil
        if let tailValue = req.query[UInt.self, at: "tail"] {
            tail = UInt(tailValue)
        }
        return try await manager.logs(for: serverID, tail: tail)
    }
    
    // MARK: - File management
    
    func download(req: Request) async throws -> Response {
        guard try await req.userHasPermissions(for: .downloadServer) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        let fileURL: URL
        do {
            fileURL = try await manager.downloadServer(with: serverID)
        }
        catch MCServerError.invalidServerId {
            throw Abort(.notFound, reason: "The requested server does not exist")
        }
        
        let downloadSession = try FileDownloadSession(for: req, url: fileURL)
        return downloadSession.get()
    }
    
    func browseFiles(req: Request) async throws -> FileBrowser {
        let serverID = try req.serverID
        let relativePath = req.query[String.self, at: "path"]
        if try await manager.file(at: relativePath ?? "", from: serverID) == nil {
            throw Abort(.notFound)
        }
        return FileBrowser(
            relativePath: relativePath,
            files: try await manager.listFiles(at: relativePath, for: serverID)
        )
    }
    
    func uploadFile(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .uploadServerFiles) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        
        let metadata = try req.query.decode(FileUploadRequest.self)
        let uploadSession = FileUploadSession(for: req, metadata: metadata)
        
        let uploadedFileURL: URL
        do {
            uploadedFileURL = try await uploadSession.get()
        }
        catch {
            logger.error("Failed to upload file")
            throw Abort(.internalServerError, reason: "Failed to upload file")
        }
        
        try await manager.saveFile(
            at: uploadedFileURL,
            for: serverID,
            to: metadata.filePath
        )
        
        return .ok
    }
    
    func removeFile(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .deleteServerFiles) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        guard let relativePath = req.query[String.self, at: "path"] else {
            throw Abort(.badRequest, reason: "Missing file path to remove in request query")
        }
        if try await manager.file(at: relativePath, from: serverID) == nil {
            throw Abort(.notFound, reason: "The specified file path does not exist")
        }
        try await manager.removeFile(at: relativePath, for: serverID)
        return .ok
    }
    
    func downloadFile(req: Request) async throws -> Response {
        guard try await req.userHasPermissions(for: .downloadServerFiles) else {
            throw Abort(.unauthorized)
        }
        let serverID = try req.serverID
        guard let relativePath = req.query[String.self, at: "path"] else {
            throw Abort(.badRequest, reason: "Missing path of file to download in request query")
        }
        guard let fileURL = try await manager.file(at: relativePath, from: serverID) else {
            throw Abort(.notFound, reason: "The specified file path does not exist")
        }
        
        let downloadSession = try FileDownloadSession(for: req, url: fileURL)
        return downloadSession.get()
    }
}

// MARK: - Helpers
extension ServerController {
    
    // Fetch the most up-to-date service settings
    func settings(on database: Database) async throws -> Settings {
        try await Settings.query(on: database).first() ?? .defaults
    }
    
    /// Load all existing servers from the given database into the current runtime
    func loadExistingServers(from database: Database) async throws {
        logger.info("Loading existing servers")
        let servers = try await MCServer.query(on: database).all()
        logger.notice("Found \(servers.count) existing server(s)")
        for server in servers {
            try await manager.add(server: server)
        }
    }
    
    /// Ensure the server is valid
    func ensureIsValid(server: MCServer, on database: Database) async throws {
        let settings = try await settings(on: database)
        // check the server port
        if !settings.allowedServerPortsData.contains(server.port) {
            throw Abort(.badRequest, reason: "Server port not in allowed range")
        }
        // TODO: check the server version against the supported runtimes?
    }
}

fileprivate extension Request {
    
    var serverID: UUID {
        get throws {
            guard let id = self.parameters.get("serverID"),
                  let uuid = UUID(uuidString: id)
            else {
                throw Abort(.badRequest, reason: "Missing server ID in request path")
            }
            return uuid
        }
    }
    
    var server: MCServer {
        get async throws {
            guard let server = try await MCServer.find(try serverID, on: self.db) else {
                throw Abort(.notFound, reason: "The requested server does not exist")
            }
            return server
        }
    }
}

fileprivate extension Settings {
    /// If the server status cache is enabled
    var serverStatusCacheIsEnabled: Bool { serverStatusCacheTTLSeconds > 0 }
}
