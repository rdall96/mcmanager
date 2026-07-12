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
            server.post("start", use: start)
            server.post("stop", use: stop)
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

            // players
            server.group("players") { players in
                players.get("operators", use: operators)
                players.post("operators", use: addOperator)
                players.delete("operators", use: removeOperator)

                players.get("whitelist", use: whitelist)
                players.post("whitelist", use: addToWhitelist)
                players.delete("whitelist", use: removeFromWhitelist)

                players.get("banned", use: bannedPlayers)
                players.post("banned", use: banPlayer)
                players.delete("banned", use: unbanPlayer)
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
            throw UserError.unauthorized
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
            throw UserError.unauthorized
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
        do {
            try await manager.update(server: server)
        }
        catch {
            logger.error("Failed to update server runtime: \(error)")
            try await server.restore(on: req.db)
            throw error
        }
        return server
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .deleteServers) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let server = try await req.server

        // Check if the server is running
        if try await manager.info(for: serverID).status == .running {
            throw MCServerError.invalidAction(.serverIsRunning)
        }

        try await server.delete(on: req.db)
        do {
            try await manager.deleteServer(id: serverID)
        }
        catch {
            logger.critical("Failed to delete server from disk, attempting to restore it. \(error)")
            try await server.restore(on: req.db)
            throw error
        }
        await deleteStatusCache(for: serverID, on: req.db)
        return .noContent
    }
    
    // MARK: - Runtime support
    
    func support(req: Request) async throws -> [MCServer.RuntimeSupport] {
        guard try await req.userHasPermissions(for: .createServers) else {
            throw UserError.unauthorized
        }

        // Check if we have cached values for the runtime support
        let cachedRuntimeSupports = try await ServerRuntimeSupportCache.query(on: req.db).all()
        let settings = try await self.settings(on: req.db)

        // This data is written all at the same time, so if the first one is expired, they all are
        if let cachedData = cachedRuntimeSupports.first,
           !settings.serverSupportCacheIsExpired(cachedData) {
            return cachedRuntimeSupports.map {
                MCServer.RuntimeSupport(with: $0)
            }
        }
        else {
            // delete the cache
            try await cachedRuntimeSupports.delete(on: req.db)
        }

        // Fetch new runtime support and cache the values
        let runtimeSupports = try await manager.allSupportedRuntimes
        for runtimeSupport in runtimeSupports {
            try await ServerRuntimeSupportCache(with: runtimeSupport).save(on: req.db)
        }

        return runtimeSupports
    }
    
    // MARK: - Status

    /// Small actor to synchronize refreshes of a server status.
    /// There are 2 endpoints in the server API that can trigger a refresh (/info and /stats) and both can be called concurrently.
    /// Whenever that happens and the cache is invalid, we end up doing duplicate work.
    /// This small objects helps reduce that overhead by blocking any duplicate requests and returning the result of the first one.
    private actor ServerStatusCacheManager{
        static let shared = ServerStatusCacheManager()

        typealias RefreshTask = Task<ServerStatusCache, Error>
        private var activeRefreshes: [MCServer.IDValue : RefreshTask] = [:]

        func serverStatus(
            for serverID: MCServer.IDValue,
            on database: Database,
            with settings: Settings,
            manager: MCServerManager
        ) async throws -> ServerStatusCache? {
            guard settings.serverStatusCacheIsEnabled else { return nil }

            // check if there's already a refresh occurring
            if let activeRefresh = activeRefreshes[serverID] {
                return try await activeRefresh.value
            }

            // create a new refresh task
            let task = RefreshTask {
                defer { activeRefreshes[serverID] = nil }

                // check if we have a valid cache in the DB
                let cachedStatus = try await ServerStatusCache.find(serverID, on: database)
                if let cachedStatus, !settings.serverStatusCacheIsExpired(cachedStatus) {
                    return cachedStatus
                }
                else {
                    // cache is either stale or invalid, delete it
                    try await cachedStatus?.delete(on: database)
                }

                // fetch a new status and save it
                let status = ServerStatusCache(
                    id: serverID,
                    info: try await manager.info(for: serverID),
                    stats: try await manager.stats(for: serverID)
                )
                try await status.save(on: database)
                return status
            }
            activeRefreshes[serverID] = task

            return try await task.value
        }
    }
    
    func info(req: Request) async throws -> MCServer.Info {
        let serverID = try req.serverID
        let status = try await ServerStatusCacheManager.shared.serverStatus(
            for: serverID,
            on: req.db,
            with: try await self.settings(on: req.db),
            manager: manager
        )
        guard let info = status?.info else {
            return try await manager.info(for: serverID)
        }
        return info
    }
    
    func stats(req: Request) async throws -> MCServer.Stats {
        let serverID = try req.serverID
        let status = try await ServerStatusCacheManager.shared.serverStatus(
            for: serverID,
            on: req.db,
            with: try await self.settings(on: req.db),
            manager: manager
        )
        guard let metrics = status?.stats else {
            return try await manager.stats(for: serverID)
        }
        return metrics
    }
    
    // MARK: - Properties & config
    
    func defaultProperties(req: Request) async throws -> MCServer.Properties {
        guard try await req.userHasPermissions(for: .readServerProperties) else {
            throw UserError.unauthorized
        }
        return MCServer.Properties.defaults
    }
    
    func properties(req: Request) async throws -> MCServer.Properties {
        guard try await req.userHasPermissions(for: .readServerProperties) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        return try await manager.properties(for: serverID)
    }
    
    func updateProperties(req: Request) async throws -> MCServer.Properties {
        guard try await req.userHasPermissions(for: .editServerProperties) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let properties = try req.content.decode(MCServer.Properties.self)
        try await manager.updateProperties(properties, for: serverID)
        return try await manager.properties(for: serverID)
    }
    
    // MARK: - Execution
    
    func start(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .startStopServers) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let settings = try await settings(on: req.db)
        guard await manager.runningServersCount < settings.maxRunningServers else {
            throw MCServerError.invalidAction(.tooManyRunningServers)
        }
        try await manager.startServer(with: serverID)
        // invalidate the status cache
        await deleteStatusCache(for: serverID, on: req.db)
        return .ok
    }
    
    func stop(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .startStopServers) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        try await manager.stopServer(with: serverID)
        // invalidate the status cache
        await deleteStatusCache(for: serverID, on: req.db)
        return .ok
    }
    
    func command(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .sendServerCommands) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        guard let command = try? req.content.decode(String.self) else {
            throw MCServerError.invalidAction(.invalidCommand)
        }
        try await manager.sendCommand(command, to: serverID)
        return .ok
    }
    
    func logs(req: Request) async throws -> [String] {
        guard try await req.userHasPermissions(for: .readServerLogs) else {
            throw UserError.unauthorized
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
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let fileURL = try await manager.downloadServer(with: serverID)
        let downloadSession = try FileDownloadSession(for: req, url: fileURL)
        return downloadSession.get()
    }
    
    func browseFiles(req: Request) async throws -> FileBrowser {
        let serverID = try req.serverID
        let relativePath = req.query[String.self, at: "path"]
        if try await manager.file(at: relativePath ?? "", from: serverID) == nil {
            throw MCServerError.invalidAction(.fileDoesNotExist)
        }
        return FileBrowser(
            relativePath: relativePath,
            files: try await manager.listFiles(at: relativePath, for: serverID)
        )
    }
    
    func uploadFile(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .uploadServerFiles) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        
        let metadata = try req.query.decode(FileUploadRequest.self)
        let uploadSession = FileUploadSession(for: req, metadata: metadata)
        
        let uploadedFileURL: URL
        do {
            uploadedFileURL = try await uploadSession.get()
        }
        catch {
            logger.error("Failed to upload file: \(error)")
            throw MCServerError.systemError(error)
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
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        guard let relativePath = req.query[String.self, at: "path"],
              try await manager.file(at: relativePath, from: serverID) != nil else {
            throw MCServerError.invalidAction(.fileDoesNotExist)
        }
        try await manager.removeFile(at: relativePath, for: serverID)
        return .ok
    }
    
    func downloadFile(req: Request) async throws -> Response {
        guard try await req.userHasPermissions(for: .downloadServerFiles) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        guard let relativePath = req.query[String.self, at: "path"],
              let fileURL = try await manager.file(at: relativePath, from: serverID) else {
            throw MCServerError.invalidAction(.fileDoesNotExist)
        }
        let downloadSession = try FileDownloadSession(for: req, url: fileURL)
        return downloadSession.get()
    }

    // MARK: Player management

    func operators(req: Request) async throws -> [MCServer.Operator] {
        // users must have the manageOperators permission
        guard try await req.userHasPermissions(for: .manageOperators) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        return Array(try await manager.operators(for: serverID))
    }

    func addOperator(req: Request) async throws -> HTTPStatus {
        // users must have the manageOperators permission
        guard try await req.userHasPermissions(for: .manageOperators) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID

        // two supported request formats
        let opAddRequest = try req.content.decode(MCServer.Operator?.self)
        let playerAddRequest = try req.content.decode(MCPlayerInfo?.self)

        // the requested player must exist
        let playerID = opAddRequest?.id ?? playerAddRequest?.id
        let playerName = opAddRequest?.name ?? playerAddRequest?.name
        guard let playerName else {
            throw MCServerError.invalidPlayerAccount
        }
        let playerInfo = try await ensurePlayerExists(playerName, id: playerID, for: req)

        // If the level is `nil` we need to fetch the default server operator level from the server properties
        var opLevel: MCServer.Operator.Level
        if let level = opAddRequest?.level {
            opLevel = level
        }
        else if let defaultOpLevel = try await manager.properties(for: serverID).opPermissionLevel {
            opLevel = defaultOpLevel
        }
        else {
            // the op level was not specified by the request, and we can't find the server default value
            // set this to a non-permissive value that won't accidentally give the player too much power
            // a user can change this by making a new request and specify the op level
            opLevel = 0
        }

        // Create the add request
        let op = MCServer.Operator(
            id: playerInfo.id,
            name: playerInfo.name,
            level: opLevel,
            ignoresPlayerLimit: opAddRequest?.ignoresPlayerLimit
        )
        try await manager.addOperator(op, on: serverID)

        return .ok
    }

    func removeOperator(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .manageOperators) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let removeRequest = try req.content.decode(MCPlayerInfo.self)

        // the requested player must exist
        let playerInfo = try await ensurePlayerExists(removeRequest.name, id: removeRequest.id, for: req)

        // remove from the list
        try await manager.removeOperator(playerInfo, on: serverID)

        return .ok
    }

    func whitelist(req: Request) async throws -> [MCPlayerInfo] {
        // all logged in users can see the whitelist, no permissions required
        let serverID = try req.serverID
        return try await manager.whitelist(for: serverID).map {
            MCPlayerInfo(id: $0.id, name: $0.name)
        }
    }

    func addToWhitelist(req: Request) async throws -> HTTPStatus {
        // users must have the manageWhitelist permission
        guard  try await req.userHasPermissions(for: .manageWhitelist) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let addRequest = try req.content.decode(MCPlayerInfo.self)

        // the requested player must exist
        let playerInfo = try await ensurePlayerExists(addRequest.name, id: addRequest.id, for: req)

        // add to whitelist
        try await manager.whitelistPlayer(playerInfo, on: serverID)

        return .ok
    }

    func removeFromWhitelist(req: Request) async throws -> HTTPStatus {
        // users must have the manageWhitelist permission
        guard  try await req.userHasPermissions(for: .manageWhitelist) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let removeRequest = try req.content.decode(MCPlayerInfo.self)

        // the requested player must exist
        let playerInfo = try await ensurePlayerExists(removeRequest.name, id: removeRequest.id, for: req)

        // remove from the list
        try await manager.removeWhitelistedPlayer(playerInfo, on: serverID)

        return .ok
    }

    func bannedPlayers(req: Request) async throws -> [MCServer.BannedPlayer] {
        // users must have the manageBannedPlayers permission
        guard try await req.userHasPermissions(for: .manageBannedPlayers) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        return Array(try await manager.bannedPlayers(for: serverID))
    }

    func banPlayer(req: Request) async throws -> HTTPStatus {
        // users must have the manageBannedPlayers permission
        guard try await req.userHasPermissions(for: .manageBannedPlayers) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID

        // two supported request formats
        let banRequest = try req.content.decode(MCServer.BannedPlayer?.self)
        let playerBanRequest = try req.content.decode(MCPlayerInfo?.self)

        // the requested player must exist
        let playerID = banRequest?.id ?? playerBanRequest?.id
        let playerName = banRequest?.name ?? playerBanRequest?.name
        guard let playerName else {
            throw MCServerError.invalidPlayerAccount
        }
        let playerInfo = try await ensurePlayerExists(playerName, id: playerID, for: req)

        // add to the ban list
        try await manager.banPlayer(playerInfo, reason: banRequest?.reason, on: serverID)

        return .ok
    }

    func unbanPlayer(req: Request) async throws -> HTTPStatus {
        // users must have the manageBannedPlayers permission
        guard  try await req.userHasPermissions(for: .manageBannedPlayers) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let removeRequest = try req.content.decode(MCPlayerInfo.self)

        // the requested player must exist
        let playerInfo = try await ensurePlayerExists(removeRequest.name, id: removeRequest.id, for: req)

        // remove from the list
        try await manager.pardonPlayer(playerInfo, on: serverID)

        return .ok
    }
}

// MARK: - Helpers
fileprivate extension ServerController {

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
            throw MCServerError.invalidPort(server.port)
        }
        // TODO: check the server version against the supported runtimes?
    }

    /// Wipe the status cache for the given server.
    func deleteStatusCache(for serverID: MCServer.IDValue, on database: Database) async {
        do {
            try await ServerStatusCache.find(serverID, on: database)?.delete(on: database)
        }
        catch {
            logger.error("Failed to delete server status cache for \(serverID): \(error)")
        }
    }

    /// Ensure a requested Minecraft account exists on Mojang's servers and return that players info.
    func ensurePlayerExists(_ playerName: String, id: MCPlayerInfo.ID, for req: Request) async throws -> MCPlayerInfo {
        let playerInfo: MCPlayerInfo
        do {
            playerInfo = try await req.client.minecraftPlayerInfo(for: playerName)
        }
        catch {
            throw MCServerError.invalidPlayerAccount
        }
        guard let playerID = playerInfo.id else {
            throw MCServerError.invalidPlayerAccount
        }
        if let requestID = id, playerID != requestID {
            throw MCServerError.invalidPlayerAccount
        }
        return playerInfo
    }
}

fileprivate extension Request {
    
    var serverID: UUID {
        get throws {
            guard let id = self.parameters.get("serverID") else {
                throw MCServerError.invalidID(nil)
            }
            guard let uuid = UUID(uuidString: id) else {
                throw MCServerError.invalidID(id)
            }
            return uuid
        }
    }
    
    var server: MCServer {
        get async throws {
            let serverID = try serverID
            let server = try await MCServer.find(serverID, on: self.db)
            guard let server else {
                throw MCServerError.notFound(serverID)
            }
            return server
        }
    }
}

fileprivate extension Settings {

    /// If the server status cache is enabled
    var serverStatusCacheIsEnabled: Bool { serverStatusCacheTTLSeconds > 0 }

    /// Determine if the server runtime support cache is expired.
    func serverStatusCacheIsExpired(_ cache: ServerStatusCache) -> Bool {
        cache.createdAt.addingTimeInterval(TimeInterval(serverStatusCacheTTLSeconds)) < .now
    }

    /// Determine if the server runtime support cache is expired.
    func serverSupportCacheIsExpired(_ cache: ServerRuntimeSupportCache) -> Bool {
        cache.createdAt.addingTimeInterval(TimeInterval(serverSupportCacheTTLSeconds)) < .now
    }
}
