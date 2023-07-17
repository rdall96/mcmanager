//
//  ServerController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
@_spi(MCManager_Server) import MCManager_Shared

struct ServerController: RouteCollection {
    typealias MCServer = Shared.Server
    
    func boot(routes: RoutesBuilder) throws {
        let servers = routes.grouped("servers")
        servers.get(use: all)
        servers.post(use: create)
        servers.group(":serverID") { server in
            server.get(use: self.server(req:))
            server.put(use: update)
            server.delete(use: delete)
        }
    }
    
    func all(req: Request) async throws -> [MCServer] {
        try await MCServer.query(on: req.db).all()
    }
    
    func create(req: Request) async throws -> MCServer {
        let server = try req.content.decode(MCServer.self)
        try await server.save(on: req.db)
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
        
        // TODO: Update server with serverRequest
        if !serverRequest.name.isEmpty {
            server.name = serverRequest.name
        }
        if !serverRequest.version.isEmpty {
            server.version = serverRequest.version
        }
        if serverRequest.port > 0, serverRequest.port != server.port {
            server.port = serverRequest.port
        }
        server.updatedAt = .now
        
        try await server.save(on: req.db)
        return server
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        guard let server = try await MCServer.find(req.parameters.get("serverID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        try await server.delete(on: req.db)
        return .noContent
    }
}
