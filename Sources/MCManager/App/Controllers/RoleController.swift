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
            
            role.get("members", use: members)
        }
        
        // default permissions
        roles.get("permissions", use: defaultPermissions)
        roles.put("permissions", use: editDefaultPermissions)
    }
    
    // MARK: - Routes
    
    func all(req: Request) async throws -> [Role] {
        let roles = try await Role.query(on: req.db).all()
        for role in roles {
            role.permissions = try await Permissions.find(role.$_permissions.id, on: req.db)
        }
        return roles
    }
    
    func create(req: Request) async throws -> Role {
        try requireAdmin(for: req) // only admins can create new roles
        let newRole = try req.content.decode(Role.self)

        // Ensure a role with this name doesn't already exists
        let existingRole = try await Role.query(on: req.db)
            .filter(\.$name, .equal, newRole.name)
            .first()
        guard existingRole == nil else {
            logger.error("Attempted to create role with duplicated name: \(newRole.name)")
            throw RoleError.alreadyExists
        }

        // create the permissions
        try await newRole.permissions?.save(on: req.db)
        // save the new role
        try await newRole.save(on: req.db)
        
        return newRole
    }
    
    func role(req: Request) async throws -> Role {
        let role = try await req.role
        role.permissions = try await Permissions.find(role.$_permissions.id, on: req.db)
        return role
    }
    
    func update(req: Request) async throws -> Role {
        try requireAdmin(for: req) // only admins can edit roles
        
        let role = try await req.role
        let roleRequest = try req.content.decode(Role.self)

        // Ensure the updated role name doesn't already exists
        let existingRoleWithRequestedName = try await Role.query(on: req.db)
            .filter(\.$name, .equal, roleRequest.name)
            .filter(\.$id, .notEqual, role.requireID())
            .first()
        guard existingRoleWithRequestedName == nil else {
            logger.error("Attempted to update role with duplicated name: \(roleRequest.name)")
            throw RoleError.alreadyExists
        }

        // update the permissions
        if let permissions = try await Permissions.find(role.$_permissions.id, on: req.db),
           let newPermissions = roleRequest.permissions {
            permissions.update(with: newPermissions)
            role.permissions = permissions
            try await permissions.save(on: req.db)
        }
        
        // update the role
        role.update(with: roleRequest)
        try await role.save(on: req.db)
        
        return role
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        try requireAdmin(for: req) // only admins can delete roles
        
        let role = try await req.role
        // Ensure there are no users with this role, otherwise this would cause a permission havoc
        let roleIsUnused = try await User.query(on: req.db)
            .filter(\.$role.$id, .equal, try role.requireID())
            .all()
            .isEmpty
        guard roleIsUnused else {
            throw Abort(.notAcceptable, reason: "There are still users with this role")
        }
        try await role.delete(on: req.db)
        try await Permissions.find(role.$_permissions.id, on: req.db)?.delete(on: req.db)
        return .noContent
    }
    
    func members(req: Request) async throws -> [User] {
        let role = try await req.role
        return try await User.query(on: req.db)
            .filter(\.$role.$id, .equal, try role.requireID())
            .all()
    }
    
    // MARK: - Default Permissions
    
    func defaultPermissions(req: Request) async throws -> Permissions {
        // must be logged in, but all users can read the default permissions
        // this is necessary for callers of the API to programmatically gate user behavior when there's no role assigned
        try requireAuthenticated(for: req)
        return try await Permissions.defaults(on: req.db) ?? .defaults
    }
    
    func editDefaultPermissions(req: Request) async throws -> Permissions {
        try requireAdmin(for: req) // only admins can manage default permissions
        let updatedPermissions = try req.content.decode(Permissions.self)
        let defaultPermissions = try await Permissions.defaults(on: req.db) ?? .defaults
        defaultPermissions.update(with: updatedPermissions)
        try await defaultPermissions.save(on: req.db)
        return updatedPermissions
    }
}

// MARK: - Helpers

fileprivate extension Request {

    var roleID: UUID {
        get throws {
            guard let id = self.parameters.get("roleID") else {
                throw RoleError.missingID
            }
            guard let uuid = UUID(uuidString: id) else {
                throw RoleError.invalidID(id)
            }
            return uuid
        }
    }

    var role: Role {
        get async throws {
            let roleID = try roleID
            let role = try await Role.find(roleID, on: self.db)
            guard let role else {
                throw RoleError.notFound(roleID)
            }
            return role
        }
    }
}
