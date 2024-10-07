//
//  File.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Vapor

struct RoleController: MCManagerAPIRoute, RouteCollection {
    let logger: Logger
    
    func boot(routes: any RoutesBuilder) throws {
        let roles = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("roles")
        
        roles.get(use: all)
        roles.post(use: create)
        roles.group(":roleID") { role in
            role.get(use: self.role)
            role.put(use: update)
            role.delete(use: delete)
        }
    }
    
    // MARK: - Routes
    
    func all(req: Request) async throws -> [Role] {
        try await Role.query(on: req.db).all()
    }
    
    func create(req: Request) async throws -> Role {
        // Only admins can create new roles
        try requireAdmin(for: req)
        let newRole = try req.content.decode(Role.self)
        try await newRole.save(on: req.db)
        return newRole
    }
    
    func role(req: Request) async throws -> Role {
        try await req.role
    }
    
    func update(req: Request) async throws -> Role {
        let role = try await req.role
        let roleRequest = try req.content.decode(Role.self)
        role.update(with: roleRequest)
        try await role.save(on: req.db)
        return role
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        let role = try await req.role
        try await role.delete(on: req.db)
        return .noContent
    }
}

// MARK: - Helpers

fileprivate extension Request {
    var role: Role {
        get async throws {
            let role = try await Role.find(self.parameters.get("roleID"), on: self.db)
            guard let role else {
                throw Abort(.notFound, reason: "The requested role does not exist")
            }
            return role
        }
    }
}
