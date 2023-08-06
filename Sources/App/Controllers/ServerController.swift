//
//  ServerController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
@_spi(MCManager_Server) import MCManager_Shared
import MinecraftRuntime

struct ServerController: RouteCollection {
    typealias MCServer = MCManager_Shared.Server
    
    let orchestra: ServerOrchestra
    
    init(serversPath: URL) throws {
        self.orchestra = try .init(serversRoot: serversPath)
    }
    
    func boot(routes: RoutesBuilder) throws {
        let servers = routes
            .grouped(SessionToken.Authenticator())
            .grouped(User.guardMiddleware())
            .grouped("servers")
        
        // management
        servers.get(use: all)
        servers.post(use: create)
        servers.group(":serverID") { server in
            server.get(use: self.server(req:))
            server.put(use: update)
            server.delete(use: delete)
            
            // status
            server.get("info", use: info)
            server.get("metrics", use: metrics)
            
            // properties & config
            server.get("configuration", use: config)
            server.put("configuration", use: updateConfig)
            server.get("icon", use: icon)
            server.put("icon", use: updateIcon)
            server.delete("icon", use: removeIcon)
            
            // execution
            server.get("start", use: start)
            server.get("stop", use: stop)
            server.get("restart", use: restart)
            server.post("command", use: command)
            server.get("logs", use: logs)
        }
        
        // runtime support
        servers.get("support", use: support)
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
        let server = try req.content.decode(MCServer.self)
        try await ensureIsValid(server: server, on: req.db)
        try await server.save(on: req.db)
        do {
            try await orchestra.add(server: server)
        }
        catch {
            try await server.delete(on: req.db)
            throw error
        }
        return server
    }
    
    func server(req: Request) async throws -> MCServer {
        guard let server = try await MCServer.find(req.parameters.get("serverID"), on: req.db)
        else { throw Abort(.notFound) }
        return server
    }
    
    func update(req: Request) async throws -> MCServer {
        let serverRequest = try req.content.decode(MCServer.self)
        guard let server = try await MCServer.find(req.parameters.get("serverID"), on: req.db)
        else { throw Abort(.notFound) }
        
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
        try await orchestra.update(server: server)
        return server
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID"),
              let server = try await MCServer.find(serverId, on: req.db)
        else {
            throw Abort(.notFound)
        }
        
        try await server.delete(on: req.db)
        do {
            try await orchestra.delete(serverWithId: serverId)
            // remove any status cache
            try await ServerStatusCache.find(serverId, on: req.db)?.delete(on: req.db)
        }
        catch {
            try await server.restore(on: req.db)
            throw error
        }
        return .noContent
    }
    
    // MARK: - Runtime support
    
    func support(req: Request) async throws -> [MCServer.RuntimeSupport] {
        return try await orchestra.allSupportedRuntimes
    }
    
    // MARK: - Status
    
    private func serverStatus(for serverId: UUID, on database: Database) async throws -> ServerStatusCache? {
        let settings = try await self.settings(on: database)
        guard settings.serverStatusCacheIsEnabled else {
            return nil
        }
        let cachedStatus = try await ServerStatusCache.find(serverId, on: database)
        if let cachedStatus, !cachedStatus.isExpired {
            return cachedStatus
        }
        else {
            // delete any previous cached status
            try await cachedStatus?.delete(on: database)
            // create a new cache
            let status = ServerStatusCache(
                id: serverId,
                ttl: settings.serverStatusCacheTTLSeconds,
                info: try await orchestra.info(for: serverId),
                metrics: try await orchestra.metrics(for: serverId)
            )
            try await status.save(on: database)
            return status
        }
    }
    
    func info(req: Request) async throws -> MCServer.Info {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        
        guard let info = try await serverStatus(for: serverId, on: req.db)?.info else {
            return try await orchestra.info(for: serverId)
        }
        return info
    }
    
    func metrics(req: Request) async throws -> MCServer.Metrics {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        
        guard let metrics = try await serverStatus(for: serverId, on: req.db)?.metrics else {
            return try await orchestra.metrics(for: serverId)
        }
        return metrics
    }
    
    // MARK: - Properties & config
    
    func config(req: Request) async throws -> [MCServer.Config] {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        return Array(try await orchestra.config(for: serverId))
    }
    
    func updateConfig(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        let config = try req.content.decode(Set<MCServer.Config>.self)
        try await orchestra.updateConfig(config, for: serverId)
        return .ok
    }
    
    func icon(req: Request) async throws -> MCServer.Icon {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        return try await orchestra.icon(for: serverId)
    }
    
    func updateIcon(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        let icon = try req.content.decode(Server.Icon.self)
        try await orchestra.updateIcon(icon, for: serverId)
        return .ok
    }
    
    func removeIcon(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        try await orchestra.removeIcon(for: serverId)
        return .ok
    }
    
    // MARK: - Execution
    
    func start(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        try await orchestra.start(serverWithId: serverId)
        // invalidate the status cache
        try await ServerStatusCache.find(serverId, on: req.db)?.delete(on: req.db)
        return .ok
    }
    
    func stop(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        try await orchestra.stop(serverWithId: serverId)
        // invalidate the status cache
        try await ServerStatusCache.find(serverId, on: req.db)?.delete(on: req.db)
        return .ok
    }
    
    func restart(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        // if we have a delay, we don't want to block this request for the lenght of that time as it can easily go over the client timeout,
        // so we launch it in a background task
        if let delay = req.query[UInt.self, at: "delay"] {
            Task(priority: .userInitiated) {
                try await orchestra.restart(serverWithId: serverId, delay: delay)
            }
        }
        else {
            try await orchestra.restart(serverWithId: serverId)
        }
        // invalidate the status cache
        try await ServerStatusCache.find(serverId, on: req.db)?.delete(on: req.db)
        return .ok
    }
    
    func command(req: Request) async throws -> HTTPStatus {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        guard let command = try? req.content.decode(String.self) else {
            throw Abort(.badRequest)
        }
        try await orchestra.send(command: command, to: serverId)
        return .ok
    }
    
    func logs(req: Request) async throws -> [String] {
        guard let serverId: UUID = req.parameters.get("serverID") else {
            throw Abort(.notFound)
        }
        var tail: UInt? = nil
        if let tailValue = req.query[UInt.self, at: "tail"] {
            tail = UInt(tailValue)
        }
        return try await orchestra.logs(for: serverId, tail: tail)
    }
}

// MARK: - Helpers
extension ServerController {
    
    // Fetch the most up-to-date service settings
    func settings(on database: Database) async throws -> Settings {
        try await Settings.query(on: database).all().first ?? .defaults
    }
    
    /// Load all existing servers from the given database into the current runtime
    func loadExistingServers(from database: Database) async throws {
        let servers = try await MCServer.query(on: database).all()
        for server in servers {
            try await orchestra.add(server: server)
        }
    }
    
    /// Ensure the server is valid
    func ensureIsValid(server: MCServer, on database: Database) async throws {
        let settings = try await settings(on: database)
        // check the server port
        if !settings.allowedServerPortsData.contains(server.port) {
            throw Abort(.badRequest, reason: "The selected server port is outside of the allowed range")
        }
    }
}
