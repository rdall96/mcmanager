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
        try await User.query(on: req.db).all()
    }

    /// Create a new user
    func create(req: Request) async throws -> User {
        // Only admins can create new users
        try requireAdmin(for: req)
        let userRequest = try req.content.decode(User.self)
        // This new user will now need its password encrypted before saving
        let user = User(
            username: userRequest.username,
            password: try User.hashPassword(userRequest.password)
        )
        try await user.save(on: req.db)
        return user
    }
    
    
    /// Get info for a specific user
    func user(req: Request) async throws -> User {
        try await req.user
    }
    
    /// Get infor for the current signed-in user
    func me(req: Request) async throws -> User {
        try req.currentUser
    }
    
    /// Update info for a user
    func update(req: Request) async throws -> User {
        let user = try await req.user
        guard try user.hasEditPermissions(for: req) else {
            throw Abort(.unauthorized)
        }
        let userRequest = try req.content.decode(User.self)
        
        // password
        if !userRequest.password.isEmpty {
            user.password = try User.hashPassword(userRequest.password)
        }
        
        // update updatedAt time
        user.updatedAt = .now
        
        try await user.save(on: req.db)
        return user
    }

    /// Delete a user
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try await req.user
        guard try user.hasEditPermissions(for: req) else {
            throw Abort(.unauthorized)
        }
        // the superuser cannot be deleted
        guard !user.isSuperAdmin else {
            logger.error("Attempted to delete default admin user, operation not allowed")
            throw Abort(.forbidden, reason: "The admin user cannot be deleted")
        }
        
        // delete existing user sessions
        try await SessionToken.query(on: req.db)
            .filter(\.$user.$id, .equal, try user.requireID())
            .all()
            .delete(on: req.db)
        
        try await user.delete(on: req.db)
        
        return .noContent
    }
}

// MARK: - Helpers

fileprivate extension Request {
    var user: User {
        get async throws {
            let user = try await User.find(self.parameters.get("userID"), on: self.db)
            guard let user else {
                throw Abort(.notFound, reason: "The requested user does not exist")
            }
            return user
        }
    }
    
    var currentUser: User {
        get throws {
            try self.auth.require(User.self)
        }
    }
}

fileprivate extension User {
    func hasEditPermissions(for req: Request) throws -> Bool {
        // only self (the current user) or an admin can edit the user
        let currentUser = try req.currentUser
        return currentUser.id == self.id || currentUser.isAdmin
    }
}
