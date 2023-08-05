//
//  UserController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import MCManager_Shared

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes
            .grouped(SessionToken.Authenticator())
            .grouped(User.guardMiddleware())
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
    
    // MARK: - Helpers
    
    private func currentUser(for req: Request) async throws -> User {
        try req.auth.require(User.self)
    }
    
    private func hasCreatePermission(for req: Request) async throws -> Bool {
        // only adminds can create new users
        let currentUser = try await currentUser(for: req)
        return currentUser.isAdmin
    }
    
    private func hasEditPermissions(_ user: User, for req: Request) async throws -> Bool {
        // only self (the current user) or an admin can edit the user
        let currentUser = try await currentUser(for: req)
        return currentUser.id == user.id || currentUser.isAdmin
    }
    
    private func deleteSessions(for user: User, on database: Database) async throws {
        let sessionTokens = try await SessionToken.query(on: database)
            .filter(\.$user.$id, .equal, try user.requireID())
            .all()
        for sessionToken in sessionTokens {
            try await sessionToken.delete(on: database)
        }
    }
    
    /// Check  if the given user is the server master (admin)
    private func isSuperuser(_ user: User) -> Bool {
        return user.id == User.admin.id
    }
    
    // MARK: - Routes

    /// List all users
    func all(req: Request) async throws -> [User] {
        try await User.query(on: req.db).all()
    }

    /// Create a new user
    func create(req: Request) async throws -> User {
        guard try await hasCreatePermission(for: req) else {
            throw Abort(.unauthorized)
        }
        let userRequest = try req.content.decode(User.self)
        // This new user will now need its password encrypted before saving
        let user = User(
            username: userRequest.username,
            password: try userRequest.hashPassword()
        )
        try await user.save(on: req.db)
        return user
    }
    
    
    /// Get info for a specific user
    func user(req: Request) async throws -> User {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db)
        else { throw Abort(.notFound) }
        return user
    }
    
    /// Get infor for the current signed-in user
    func me(req: Request) async throws -> User {
        try await currentUser(for: req)
    }
    
    /// Update info for a user
    func update(req: Request) async throws -> User {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard try await hasEditPermissions(user, for: req) else {
            throw Abort(.unauthorized)
        }
        let userRequest = try req.content.decode(User.self)
        
        // password
        if !userRequest.password.isEmpty {
            user.password = try userRequest.hashPassword()
        }
        
        // update updatedAt time
        user.updatedAt = .now
        
        try await user.save(on: req.db)
        return user
    }

    /// Delete a user
    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard try await hasEditPermissions(user, for: req) else {
            throw Abort(.unauthorized)
        }
        // the superuser cannot be deleted
        guard !isSuperuser(user) else {
            throw Abort(.custom(code: 400, reasonPhrase: "The admin user cannot be deleted"))
        }
        try await deleteSessions(for: user, on: req.db)
        try await user.delete(on: req.db)
        return .noContent
    }
}
