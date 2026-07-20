//
//  RoleController.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Fluent
import Vapor

struct RoleController: MCManagerAPIRoute, RouteCollection {
    let logger: Logger
    
    func boot(routes: any RoutesBuilder) throws {
        let roles = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("roles")
            .openAPIMetadata(tags: .roles, requiresAuthentication: true)

        // Fetch all roles
        roles.get(use: all)
            .openAPIMetadata(
                summary: "Fetch all roles",
                responses: .rolesResponse
            )

        /// Create a new role.
        roles.post(use: create)
            .openAPIMetadata(
                summary: "Create a new role",
                request: .roleRequest,
                responses: .roleResponse, .adminRequiredResponse, .duplicateRoleResponse
            )

        // Role routes
        let role = roles.grouped(":roleID")
            .openAPIResponse(.roleNotFoundResponse)

        // Fetch a role
        role.get(use: self.role)
            .openAPIMetadata(
                summary: "Fetch a role",
                responses: .roleResponse
            )

        // Edit a role
        role.put(use: update)
            .openAPIMetadata(
                summary: "Edit a role",
                request: .roleRequest,
                responses: .roleResponse, .adminRequiredResponse, .duplicateRoleResponse
            )

        // Delete a role
        role.delete(use: delete)
            .openAPIMetadata(
                summary: "Delete a role",
                responses: .success("Role deleted"), .adminRequiredResponse
            )

        // Get the user members of a role
        role.get("members", use: members)
            .openAPIMetadata(
                summary: "Get the user members of a role",
                responses: .usersResponse
            )

        // Fetch default user permissions (for users without a role)
        roles.get("permissions", use: defaultPermissions)
            .openAPIMetadata(
                summary: "Fetch default user permissions",
                responses: .defaultPermissionsResponse
            )

        // Edit default user permissions
        roles.put("permissions", use: editDefaultPermissions)
            .openAPIMetadata(
                summary: "Edit default user permissions",
                request: .permissionsRequest,
                responses: .defaultPermissionsResponse, .adminRequiredResponse
            )
    }
    
    // MARK: - Routes
    
    func all(req: Request) async throws -> [RoleResponse] {
        let roles = try await Role.query(on: req.db).all()
        var response: [RoleResponse] = []
        for role in roles {
            guard let permissions = try await Permissions.find(role.$permissions.id, on: req.db) else {
                throw RoleError.missingPermissions
            }
            response.append(try RoleResponse(role: role, permissions: permissions))
        }
        return response
    }
    
    func create(req: Request) async throws -> RoleResponse {
        try requireAdmin(for: req) // only admins can create new roles
        let createRequest = try req.content.decode(RoleRequest.self)

        // Ensure a role with this name doesn't already exists
        let existingRole = try await Role.query(on: req.db)
            .filter(\.$name, .equal, createRequest.name)
            .first()
        guard existingRole == nil else {
            logger.error("Attempted to create role with duplicated name: \(createRequest.name)")
            throw RoleError.alreadyExists
        }

        // create the permissions
        let newPermissions = Permissions(with: createRequest)
        try await newPermissions.save(on: req.db)

        // create the role
        let newRole = try Role(name: createRequest.name, permissions: newPermissions)
        try await newRole.save(on: req.db)
        
        return try RoleResponse(role: newRole, permissions: newPermissions)
    }
    
    func role(req: Request) async throws -> RoleResponse {
        let role = try await req.role
        let permissions = try await req.permissions
        return try RoleResponse(role: role, permissions: permissions)
    }
    
    func update(req: Request) async throws -> RoleResponse {
        try requireAdmin(for: req) // only admins can edit roles
        
        let role = try await req.role
        let permissions = try await req.permissions
        let editRequest = try req.content.decode(RoleRequest.self)

        // Ensure the updated role name doesn't already exists
        let existingRoleWithRequestedName = try await Role.query(on: req.db)
            .filter(\.$name, .equal, editRequest.name)
            .filter(\.$id, .notEqual, role.requireID())
            .first()
        guard existingRoleWithRequestedName == nil else {
            logger.error("Attempted to update role with duplicated name: \(editRequest.name)")
            throw RoleError.alreadyExists
        }

        // update the permissions
        permissions.update(with: editRequest)
        try await permissions.save(on: req.db)
        
        // update the role
        try role.update(with: editRequest)
        try await role.save(on: req.db)
        
        return try RoleResponse(role: role, permissions: permissions)
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        try requireAdmin(for: req) // only admins can delete roles
        
        let role = try await req.role
        let permissions = try await req.permissions

        // Ensure there are no users with this role, otherwise this would cause a permission havoc
        let roleIsUnused = try await User.query(on: req.db)
            .filter(\.$role.$id, .equal, try role.requireID())
            .all()
            .isEmpty
        guard roleIsUnused else {
            throw RoleError.cantDelete
        }
        try await role.delete(on: req.db)
        try await permissions.delete(on: req.db)
        return .ok
    }
    
    func members(req: Request) async throws -> [User] {
        // use the role here, not just the role ID, to ensure the role is valid and exists
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
        let editRequest = try req.content.decode(PermissionsRequest.self)
        let defaultPermissions = try await Permissions.defaults(on: req.db) ?? .defaults
        defaultPermissions.update(with: editRequest)
        try await defaultPermissions.save(on: req.db)
        return try await Permissions.defaults(on: req.db) ?? .defaults
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
                throw RoleError.notFound
            }
            return role
        }
    }

    var permissions: Permissions {
        get async throws {
            let role = try await self.role
            let permissions = try await Permissions.find(role.$permissions.id, on: self.db)
            guard let permissions else {
                throw RoleError.missingPermissions
            }
            return permissions
        }
    }
}
