//
//  UserController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor

struct UserController: MCManagerAPIRoute, RouteCollection {
    let logger: Logger
    
    func boot(routes: any RoutesBuilder) throws {
        let users = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("users")
            .openAPIMetadata(tags: .users, requiresAuthentication: true)

        // Fetch all users
        users.get(use: all)
            .openAPIMetadata(
                summary: "Fetch all users",
                permissions: Permissions(users: .readUsers),
                responses: .usersResponse
            )

        // Fetch current user
        users.get("profile", use: me)
            .openAPIMetadata(
                summary: "Fetch the current user",
                responses: .userResponse
            )

        // Create a new user
        users.post(use: create)
            .openAPIMetadata(
                summary: "Create a new user",
                request: .userRequest,
                permissions: Permissions(users: .createUsers),
                responses: .userResponse, .adminRequiredResponse, .duplicateUserResponse
            )

        // User routes
        let user = users.grouped(":userID")
            .openAPIResponse(.userNotFoundResponse)

        // Fetch a user
        user.get(use: self.user(req:))
            .openAPIMetadata(
                summary: "Fetch a user",
                permissions: Permissions(users: .readUsers),
                responses: .userResponse
            )

        // Edit a user
        user.put(use: update)
            .openAPIMetadata(
                summary: "Edit a user",
                request: .userRequest,
                permissions: Permissions(users: .editUsers),
                responses: .userResponse, .adminRequiredResponse, .duplicateUserResponse
            )

        // Delete a user
        user.delete(use: delete)
            .openAPIMetadata(
                summary: "Delete a user",
                permissions: Permissions(users: .deleteUsers),
                responses: .success("User deleted"), .cantDeleteAdminResponse
            )
    }
    
    // MARK: - Routes

    /// List all users
    func all(req: Request) async throws -> [User] {
        guard try await req.userHasPermissions(for: .readUsers) else {
            throw UserError.unauthorized
        }
        return try await User.query(on: req.db).all()
    }

    /// Create a new user
    func create(req: Request) async throws -> User {
        guard try await req.userHasPermissions(for: .createUsers) else {
            throw UserError.unauthorized
        }
        let createRequest = try req.content.decode(UserRequest.self)

        // Only admins can create other admins
        if createRequest.isAdmin, !(try req.currentUser.isAdmin) {
            throw UserError.adminRequired
        }

        // Check if a user with this username already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\.$username, .equal, createRequest.username)
            .first()
        guard existingUser == nil else {
            logger.error("Attempted to create user with duplicated username: \(createRequest.username)")
            throw UserError.alreadyExists
        }

        // This new user will now need its password encrypted before saving
        let newUser = try User(with: createRequest)
        do {
            try await newUser.save(on: req.db)
        }
        catch {
            logger.critical("Faield to create new user: \(error)")
            throw Abort(.internalServerError)
        }
        return newUser
    }
    
    /// Get info for a specific user
    func user(req: Request) async throws -> User {
        let user = try await req.user
        let hasPermissions = try await req.userHasPermissions(for: .readUsers)
        guard try user.isCurrentUser(for: req) || hasPermissions else {
            throw UserError.unauthorized
        }
        return user
    }
    
    /// Get infor for the current signed-in user
    func me(req: Request) async throws -> User {
        try req.currentUser
    }
    
    /// Update info for a user
    func update(req: Request) async throws -> User {
        // Gather necessary data and decode request
        let user = try await req.user
        let hasPermissions = try await req.userHasPermissions(for: .editUsers)
        let editRequest = try req.content.decode(UserRequest.self)
        guard try user.isCurrentUser(for: req) || hasPermissions else {
            throw UserError.unauthorized
        }

        // Hard checks:
        // * only the super admin can edit itself
        if user.isAdmin, !(try user.isCurrentUser(for: req)), !(try req.currentUser.isSuperAdmin) {
            throw UserError.unauthorized
        }
        // * only the super admin can grant/revoke admin access
        if user.isAdmin != editRequest.isAdmin, !(try req.currentUser.isSuperAdmin) {
            throw UserError.adminRequired
        }
        // * the requested role must exist
        if user.$role.id != editRequest.role, let newRoleID = editRequest.role,
           try await Role.find(newRoleID, on: req.db) == nil {
            throw UserError.invalidRole
        }
        // * a user can't change it's own role (regardless of permissions)
        if try user.isCurrentUser(for: req), user.$role.id != editRequest.role {
            throw UserError.unauthorized
        }
        // * duplicate username
        let existingUserWithRequestedName = try await User.query(on: req.db)
            .filter(\.$username, .equal, editRequest.username)
            .filter(\.$id, .notEqual, user.requireID())
            .first()
        guard existingUserWithRequestedName == nil else {
            logger.error("Attempted to update user with duplicated username: \(editRequest.username)")
            throw UserError.alreadyExists
        }

        // Update the user
        try user.update(with: editRequest)

        // Save the user and return the updated model
        try await user.save(on: req.db)
        return user
    }

    /// Delete a user
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try await req.user
        let hasPermissions = try await req.userHasPermissions(for: .deleteUsers)
        guard try user.isCurrentUser(for: req) || hasPermissions else {
            throw UserError.unauthorized
        }
        // the superuser cannot be deleted
        if user.isSuperAdmin {
            throw UserError.cantDeleteAdmin
        }
        
        // delete existing user sessions
        try await SessionToken.query(on: req.db)
            .filter(\.$user.$id, .equal, try user.requireID())
            .delete()
        
        try await user.delete(on: req.db)
        
        return .ok
    }
}

// MARK: - Helpers

fileprivate extension Request {
    
    var userID: UUID {
        get throws {
            guard let id = self.parameters.get("userID") else {
                throw UserError.missingID
            }
            guard let uuid = UUID(uuidString: id) else {
                throw UserError.invalidID
            }
            return uuid
        }
    }
    
    var user: User {
        get async throws {
            let userID = try userID
            let user = try await User.find(userID, on: self.db)
            guard let user else {
                throw UserError.notFound
            }
            return user
        }
    }
    
    var currentUser: User {
        get throws {
            do {
                return try self.auth.require(User.self)
            }
            catch {
                throw AuthenticationError.notAuthenticated
            }
        }
    }
}

fileprivate extension User {
    func isCurrentUser(for req: Request) throws -> Bool {
        let currentUser = try req.currentUser
        return try requireID() == currentUser.id
    }
}
