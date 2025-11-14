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
    
    func boot(routes: RoutesBuilder) throws {
        let users = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("users")
        users.get(use: all)
        users.get("profile", use: me)
        users.post(use: create)
        users.group(":userID") { user in
            user.get(use: self.user(req:))
            user.put(use: update)
            user.delete(use: delete)
        }
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
        let userRequest = try req.content.decode(User.self)

        // Only admins can create other admins
        if userRequest.isAdmin, !(try req.currentUser.isAdmin) {
            throw UserError.adminRequired
        }

        // Check if a user with this username already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\.$username, .equal, userRequest.username)
            .first()
        guard existingUser == nil else {
            logger.error("Attempted to create user with duplicated username: \(userRequest.username)")
            throw UserError.alreadyExists
        }

        // This new user will now need its password encrypted before saving
        let newUser = try User(
            username: userRequest.username,
            password: userRequest.password,
            isAdmin: userRequest.isAdmin,
            roleID: userRequest.$role.id
        )
        do {
            try await newUser.save(on: req.db)
        }
        catch {
            logger.critical("Faield to create new user: \(error)")
            throw UserError.unknown
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
        let user = try await req.user
        let hasPermissions = try await req.userHasPermissions(for: .editUsers)
        guard try user.isCurrentUser(for: req) || hasPermissions else {
            throw UserError.unauthorized
        }
        
        // only the super admin can edit itself
        if user.isAdmin, !(try user.isCurrentUser(for: req)), !(try req.currentUser.isSuperAdmin) {
            throw UserError.unauthorized
        }
        
        let userRequest = try req.content.decode(User.self)
        try user.update(with: userRequest)
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
        
        return .noContent
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
                throw UserError.invalidID(id)
            }
            return uuid
        }
    }
    
    var user: User {
        get async throws {
            let userID = try userID
            let user = try await User.find(userID, on: self.db)
            guard let user else {
                throw UserError.notFound(userID)
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
