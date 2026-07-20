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
    let manager: MinecraftServerManager
    
    init(serversPath: URL, database: any Database, logger: Logger) async throws {
        self.manager = try .init(serversRoot: serversPath, logger: logger)
        self.logger = logger
        
        try await loadExistingServers(from: database)
    }
    
    func boot(routes: any RoutesBuilder) throws {
        // V1 APIs
        let servers = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("servers")
            .openAPIMetadata(tags: .servers, requiresAuthentication: true)

        // Fetch the supported server runtimes
        servers.get("support", use: support)
            .openAPIMetadata(
                summary: "Fetch the supported server runtimes",
                permissions: Permissions(servers: .createServers),
                responses: .serverRuntimeSupportResponse
            )

        // Fetch the default server properties
        servers.get("properties", use: defaultProperties)
            .openAPIMetadata(
                summary: "Fetch the default server properties",
                tag: .serverProperties,
                permissions: Permissions(servers: .readServerProperties),
                responses: .serverPropertiesResponse
            )

        // Fetch all servers
        servers.get(use: all)
            .openAPIMetadata(
                summary: "Fetch all servers",
                request: .fetchServersRequest,
                responses: .minecraftServersResponse
            )

        // Create a server
        servers.post(use: create)
            .openAPIMetadata(
                summary: "Create a server",
                request: .serverCreateRequest,
                permissions: Permissions(servers: .createServers),
                responses: .minecraftServerResponse
            )

        // Server operations
        let server = servers.grouped(":serverID")
            .openAPIResponse(.serverNotFoundResponse)
        // Fetch a server
        server.get(use: self.server(req:))
            .openAPIMetadata(
                summary: "Fetch a server",
                responses: .minecraftServerResponse
            )
        // Edit a server
        server.put(use: update)
            .openAPIMetadata(
                summary: "Edit a server",
                request: .serverEditRequest,
                permissions: Permissions(servers: .editServers),
                responses: .minecraftServerResponse
            )
        // Delete a server
        server.delete(use: delete)
            .openAPIMetadata(
                summary: "Delete a server",
                permissions: Permissions(servers: .deleteServers),
                responses: .success("Server deleted")
            )
        // Fetch the status of a server
        server.get("info", use: info)
            .openAPIMetadata(
                summary: "Fetch the status of a server",
                responses: .serverInfoResponse
            )
        // Fetch the system resources usage of a server
        server.get("stats", use: stats)
            .openAPIMetadata(
                summary: "Fetch the system resources usage of a server",
                responses: .serverStatsResponse
            )
        // Fetch Minecraft server properties
        server.get("properties", use: properties)
            .openAPIMetadata(
                summary: "Fetch Minecraft server properties",
                tag: .serverProperties,
                permissions: Permissions(servers: .readServerProperties),
                responses: .serverPropertiesResponse
            )
        // Edit Minecraft server properties
        server.put("properties", use: updateProperties)
            .openAPIMetadata(
                summary: "Edit Minecraft server properties",
                tag: .serverProperties,
                request: .serverPropertiesRequest,
                permissions: Permissions(servers: .editServerProperties),
                responses: .serverPropertiesResponse
            )
        // Start a Minecraft server
        server.post("start", use: start)
            .openAPIMetadata(
                summary: "Start a Minecraft server",
                permissions: Permissions(servers: .startStopServers),
                responses: .success("Server started"), .maxRunningServersLimitReachedResponse, .serverPortInUseResponse, .serverRunningResponse
            )
        // Stop a Minecraft server
        server.post("stop", use: stop)
            .openAPIMetadata(
                summary: "Stop a Minecraft server",
                permissions: Permissions(servers: .startStopServers),
                responses: .success("Server stopped"), .serverStoppedResponse
            )
        // Send a command to a Minecraft server
        server.post("command", use: command)
            .openAPIMetadata(
                summary: "Send a command to a Minecraft server",
                request: .sendServerCommandRequest,
                permissions: Permissions(servers: .sendServerCommands),
                responses: .success("Command sent"), .serverStoppedResponse
            )
        // Fetch the Minecraft server logs
        server.get("logs", use: logs)
            .openAPIMetadata(
                summary: "Fetch the Minecraft server logs",
                request: .fetchServerLogsRequest,
                permissions: Permissions(servers: .readServerLogs),
                responses: .serverLogsResponse
            )

        // Download server zip
        server.get("download", use: download)
            .openAPIMetadata(
                summary: "Download server zip",
                tag: .serverFiles,
                permissions: Permissions(servers: .downloadServer),
                responses: .serverArchiveResponse, .serverRunningResponse
            )

        // Serer files
        let serverFiles = server.grouped("files")
            .openAPIMetadata(tags: .serverFiles)
        // Browse server files
        serverFiles.get("browse", use: browseFiles)
            .openAPIMetadata(
                summary: "Browse server files",
                request: .serverFilesRequest,
                responses: .serverFilesResponse, .serverFileDoesNotExistResponse
            )
        // Download a server file
        serverFiles.get(use: downloadFile)
            .openAPIMetadata(
                summary: "Download a server file",
                request: .serverFilesRequest,
                permissions: Permissions(servers: .downloadServerFiles),
                responses: .serverFileDownloadResponse, .serverFileDoesNotExistResponse
            )
        // Upload a file to the server directory
        serverFiles.on(.POST, body: .stream, use: uploadFile)
            .openAPIMetadata(
                summary: "Upload a file to the server directory",
                request: .serverFileUploadRequest,
                permissions: Permissions(servers: .uploadServerFiles),
                responses: .success("File uploaded")
            )
        // Delete a server file
        serverFiles.delete(use: removeFile)
            .openAPIMetadata(
                summary: "Delete a server file",
                request: .serverFilesRequest,
                permissions: Permissions(servers: .deleteServerFiles),
                responses: .success("File deleted"), .serverFileDoesNotExistResponse
            )

        // Player configurations
        let players = server.grouped("players")
            .openAPIMetadata(tags: .serverPlayerManagement)

        // Fetch the server operators
        players.get("operators", use: operators)
            .openAPIMetadata(
                summary: "Fetch the server operators",
                permissions: Permissions(servers: .manageOperators),
                responses: .serverOperatorsResponse
            )
        // Add a server operator
        players.post("operators", use: addOperator)
            .openAPIMetadata(
                summary: "Add a server operator",
                request: .addServerOperatorRequest,
                permissions: Permissions(servers: .manageOperators),
                responses: .success("Operator added")
            )
        // Remove a server operator
        players.delete("operators", use: removeOperator)
            .openAPIMetadata(
                summary: "Remove a server operator",
                request: .removeServerOperatorRequest,
                permissions: Permissions(servers: .manageOperators),
                responses: .success("Operator removed")
            )

        // Fetch the server whitelist
        players.get("whitelist", use: whitelist)
            .openAPIMetadata(
                summary: "Fetch the server whitelist",
                responses: .serverWhitelistResponse
            )
        // Add a player to the server whitelist
        players.post("whitelist", use: addToWhitelist)
            .openAPIMetadata(
                summary: "Add a player to the server whitelist",
                request: .addWhitelistedPlayerRequest,
                permissions: Permissions(servers: .manageWhitelist),
                responses: .success("Player added")
            )
        // Remove a player from the server whitelist
        players.delete("whitelist", use: removeFromWhitelist)
            .openAPIMetadata(
                summary: "Remove a player from the server whitelist",
                request: .removeWhitelistedPlayerRequest,
                permissions: Permissions(servers: .manageWhitelist),
                responses: .success("Player removed")
            )

        // Fetch the banned players on a server
        players.get("banned", use: bannedPlayers)
            .openAPIMetadata(
                summary: "Fetch the banned players on a server",
                permissions: Permissions(servers: .manageBannedPlayers),
                responses: .serverBannedPlayersResponse
            )
        // Ban a player on the server
        players.post("banned", use: banPlayer)
            .openAPIMetadata(
                summary: "Ban a player on the server",
                request: .banPlayerRequest,
                permissions: Permissions(servers: .manageBannedPlayers),
                responses: .success("Player banned")
            )
        // Pardon a player on the server (remove the ban)
        players.delete("banned", use: unbanPlayer)
            .openAPIMetadata(
                summary: "Pardon a player on the server (remove the ban)",
                request: .pardonPlayerRequest,
                permissions: Permissions(servers: .manageBannedPlayers),
                responses: .success("Player pardoned")
            )
    }
    
    // MARK: - Server management
    
    func all(req: Request) async throws -> [MinecraftServer] {
        let fetchRequest = try req.query.decode(MinecraftServerFetchRequest.self)

        // Collect all the query filters:
        var filters: [DatabaseQuery.Filter] = []
        // * server type
        if let serverType = fetchRequest.type {
            filters.append(.value(
                .path([MinecraftServer.FieldKeys.type.rawValue], schema: MinecraftServer.schema),
                .equal,
                .enumCase(serverType.rawValue)
            ))
        }

        var query = MinecraftServer.query(on: req.db)
        for filter in filters {
            query = query.filter(filter)
        }
        return try await query.all()
    }
    
    func create(req: Request) async throws -> MinecraftServer {
        guard try await req.userHasPermissions(for: .createServers) else {
            throw UserError.unauthorized
        }
        let createRequest = try req.content.decode(MinecraftServerRequest.self)
        let settings = try await settings(on: req.db)

        // Create the new server
        let newServer = try MinecraftServer(with: createRequest, settings: settings)
        try await newServer.save(on: req.db)
        do {
            try await manager.add(server: newServer)
        }
        catch {
            logger.critical("Failed to create server runtime: \(error)")
            try await newServer.delete(on: req.db)
            throw error
        }
        return newServer
    }
    
    func server(req: Request) async throws -> MinecraftServer {
        try await req.server
    }
    
    func update(req: Request) async throws -> MinecraftServer {
        guard try await req.userHasPermissions(for: .editServers) else {
            throw UserError.unauthorized
        }
        let server = try await req.server
        let editRequest = try req.content.decode(MinecraftServerRequest.self)
        let settings = try await settings(on: req.db)

        // Update the server (also validates update request)
        try server.update(with: editRequest, settings: settings)

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
        let serverStatus = try await manager.info(for: serverID).status
        if case .running = serverStatus {
            throw MinecraftServerError.running
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
        return .ok
    }
    
    // MARK: - Runtime support
    
    func support(req: Request) async throws -> [MinecraftServer.RuntimeSupport] {
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
                MinecraftServer.RuntimeSupport(with: $0)
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

        typealias RefreshTask = Task<ServerStatusCache, any Error>
        private var activeRefreshes: [MinecraftServer.IDValue : RefreshTask] = [:]

        func serverStatus(
            for serverID: MinecraftServer.IDValue,
            on database: any Database,
            with settings: Settings,
            manager: MinecraftServerManager
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
    
    func info(req: Request) async throws -> MinecraftServer.Info {
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
    
    func stats(req: Request) async throws -> MinecraftServer.Stats {
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
    
    func defaultProperties(req: Request) async throws -> MinecraftServer.Properties {
        guard try await req.userHasPermissions(for: .readServerProperties) else {
            throw UserError.unauthorized
        }
        return MinecraftServer.Properties.defaults
    }
    
    func properties(req: Request) async throws -> MinecraftServer.Properties {
        guard try await req.userHasPermissions(for: .readServerProperties) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        return try await manager.properties(for: serverID)
    }
    
    func updateProperties(req: Request) async throws -> MinecraftServer.Properties {
        guard try await req.userHasPermissions(for: .editServerProperties) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let properties = try req.content.decode(MinecraftServer.Properties.self)
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
            throw MinecraftServerError.tooManyRunningServers
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
            throw MinecraftServerError.invalidCommand
        }
        try await manager.sendCommand(command, to: serverID)
        return .ok
    }
    
    func logs(req: Request) async throws -> [String] {
        guard try await req.userHasPermissions(for: .readServerLogs) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let fetchRequest = try req.query.decode(MinecraftServerFetchLogsRequest.self)

        return try await manager.logs(for: serverID, tail: fetchRequest.tail)
    }
    
    // MARK: - File management
    
    func download(req: Request) async throws -> Response {
        guard try await req.userHasPermissions(for: .downloadServer) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let fileURL = try await manager.downloadServer(with: serverID)
        let downloadSession = try FileDownloadSession(for: req, url: fileURL)
        return try await downloadSession.get()
    }
    
    func browseFiles(req: Request) async throws -> FileBrowser {
        let serverID = try req.serverID
        let fileRequest = try req.query.decode(FileRequest.self)
        let relativePath = fileRequest.path ?? ""
        if try await manager.file(at: relativePath, from: serverID) == nil {
            throw MinecraftServerError.fileDoesNotExist
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
            throw MinecraftServerError.systemError(error)
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
        let fileRequest = try req.query.decode(FileRequest.self)
        guard let filePath = fileRequest.path,
              try await manager.file(at: filePath, from: serverID) != nil else {
            throw MinecraftServerError.fileDoesNotExist
        }
        try await manager.removeFile(at: filePath, for: serverID)
        return .ok
    }
    
    func downloadFile(req: Request) async throws -> Response {
        guard try await req.userHasPermissions(for: .downloadServerFiles) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let fileRequest = try req.query.decode(FileRequest.self)
        guard let filePath = fileRequest.path,
              let fileURL = try await manager.file(at: filePath, from: serverID) else {
            throw MinecraftServerError.fileDoesNotExist
        }
        let downloadSession = try FileDownloadSession(for: req, url: fileURL)
        return try await downloadSession.get()
    }

    // MARK: Player management

    func operators(req: Request) async throws -> [MinecraftServer.Operator] {
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
        let opAddRequest = try req.content.decode(MinecraftServer.Operator?.self)
        let playerAddRequest = try req.content.decode(MinecraftPlayerInfo?.self)

        // the requested player must exist
        let playerID = opAddRequest?.id ?? playerAddRequest?.id
        let playerName = opAddRequest?.name ?? playerAddRequest?.name
        guard let playerName else {
            throw MinecraftServerError.invalidPlayerAccount
        }
        let playerInfo = try await ensurePlayerExists(playerName, id: playerID, for: req)

        // If the level is `nil` we need to fetch the default server operator level from the server properties
        var opLevel: MinecraftServer.Operator.Level
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
        let op = MinecraftServer.Operator(
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
        let removeRequest = try req.content.decode(MinecraftPlayerInfo.self)

        // the requested player must exist
        let playerInfo = try await ensurePlayerExists(removeRequest.name, id: removeRequest.id, for: req)

        // remove from the list
        try await manager.removeOperator(playerInfo, on: serverID)

        return .ok
    }

    func whitelist(req: Request) async throws -> [MinecraftPlayerInfo] {
        // all logged in users can see the whitelist, no permissions required
        let serverID = try req.serverID
        return try await manager.whitelist(for: serverID).map {
            MinecraftPlayerInfo(id: $0.id, name: $0.name)
        }
    }

    func addToWhitelist(req: Request) async throws -> HTTPStatus {
        // users must have the manageWhitelist permission
        guard  try await req.userHasPermissions(for: .manageWhitelist) else {
            throw UserError.unauthorized
        }
        let serverID = try req.serverID
        let addRequest = try req.content.decode(MinecraftPlayerInfo.self)

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
        let removeRequest = try req.content.decode(MinecraftPlayerInfo.self)

        // the requested player must exist
        let playerInfo = try await ensurePlayerExists(removeRequest.name, id: removeRequest.id, for: req)

        // remove from the list
        try await manager.removeWhitelistedPlayer(playerInfo, on: serverID)

        return .ok
    }

    func bannedPlayers(req: Request) async throws -> [MinecraftServer.BannedPlayer] {
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
        let banRequest = try req.content.decode(MinecraftServer.BannedPlayer?.self)
        let playerBanRequest = try req.content.decode(MinecraftPlayerInfo?.self)

        // the requested player must exist
        let playerID = banRequest?.id ?? playerBanRequest?.id
        let playerName = banRequest?.name ?? playerBanRequest?.name
        guard let playerName else {
            throw MinecraftServerError.invalidPlayerAccount
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
        let removeRequest = try req.content.decode(MinecraftPlayerInfo.self)

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
    func settings(on database: any Database) async throws -> Settings {
        try await Settings.query(on: database).first() ?? .defaults
    }
    
    /// Load all existing servers from the given database into the current runtime
    func loadExistingServers(from database: any Database) async throws {
        logger.info("Loading existing servers")
        let servers = try await MinecraftServer.query(on: database).all()
        logger.notice("Found \(servers.count) existing server(s)")
        for server in servers {
            try await manager.add(server: server)
        }
    }

    /// Wipe the status cache for the given server.
    func deleteStatusCache(for serverID: MinecraftServer.IDValue, on database: any Database) async {
        do {
            try await ServerStatusCache.find(serverID, on: database)?.delete(on: database)
        }
        catch {
            logger.error("Failed to delete server status cache for \(serverID): \(error)")
        }
    }

    /// Ensure a requested Minecraft account exists on Mojang's servers and return that players info.
    func ensurePlayerExists(_ playerName: String, id: MinecraftPlayerInfo.ID, for req: Request) async throws -> MinecraftPlayerInfo {
        let playerInfo: MinecraftPlayerInfo
        do {
            playerInfo = try await req.client.minecraftPlayerInfo(for: playerName)
        }
        catch {
            throw MinecraftServerError.invalidPlayerAccount
        }
        guard let playerID = playerInfo.id else {
            throw MinecraftServerError.invalidPlayerAccount
        }
        if let requestID = id, playerID != requestID {
            throw MinecraftServerError.invalidPlayerAccount
        }
        return playerInfo
    }
}

fileprivate extension Request {
    
    var serverID: UUID {
        get throws {
            guard let id = self.parameters.get("serverID") else {
                throw MinecraftServerError.invalidID
            }
            guard let uuid = UUID(uuidString: id) else {
                throw MinecraftServerError.invalidID
            }
            return uuid
        }
    }
    
    var server: MinecraftServer {
        get async throws {
            let serverID = try serverID
            let server = try await MinecraftServer.find(serverID, on: self.db)
            guard let server else {
                throw MinecraftServerError.notFound
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
