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
            
            user.get("role", use: role)
        }
    }
    
    // MARK: - Routes

    /// List all users
    func all(req: Request) async throws -> [User] {
        guard try await req.userHasPermissions(for: .readUsers) else {
            throw Abort(.unauthorized)
        }
        return try await User.query(on: req.db).all()
    }

    /// Create a new user
    func create(req: Request) async throws -> User {
        guard try await req.userHasPermissions(for: .createUsers) else {
            throw Abort(.unauthorized)
        }
        let userRequest = try req.content.decode(User.self)
        // This new user will now need its password encrypted before saving
        let newUser = try User(username: userRequest.username, password: userRequest.password)
        try await newUser.save(on: req.db)
        return newUser
    }
    
    
    /// Get info for a specific user
    func user(req: Request) async throws -> User {
        let user = try await req.user
        let hasPermissions = try await req.userHasPermissions(for: .readUsers)
        guard try user.isCurrentUser(for: req) || hasPermissions else {
            throw Abort(.unauthorized)
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
            throw Abort(.unauthorized)
        }
        
        // only the super admin can edit itself
        if user.isSuperAdmin, !(try user.isCurrentUser(for: req)) {
            logger.error("Attempted to edit the super admin, operation not allowed")
            throw Abort(.forbidden, reason: "Only the super admin can edit itself")
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
            throw Abort(.unauthorized)
        }
        // the superuser cannot be deleted
        if user.isSuperAdmin {
            logger.error("Attempted to delete default admin user, operation not allowed")
            throw Abort(.forbidden, reason: "The super admin user cannot be deleted")
        }
        
        // delete existing user sessions
        try await SessionToken.query(on: req.db)
            .filter(\.$user.$id, .equal, try user.requireID())
            .delete()
        
        try await user.delete(on: req.db)
        
        return .noContent
    }
    
    func role(req: Request) async throws -> Role {
        let user = try await req.user
        guard let roleID = user.$role.id,
              let role = try await Role.find(roleID, on: req.db)
        else {
            throw Abort(.notFound)
        }
        return role
    }
}

// MARK: - Helpers

fileprivate extension Request {
    
    var userID: UUID {
        get throws {
            guard let id = self.parameters.get("userID"),
                  let uuid = UUID(uuidString: id)
            else {
                throw Abort(.badRequest, reason: "Missing user ID in request path")
            }
            return uuid
        }
    }
    
    var user: User {
        get async throws {
            let user = try await User.find(try userID, on: self.db)
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
    func isCurrentUser(for req: Request) throws -> Bool {
        let currentUser = try req.currentUser
        return try requireID() == currentUser.id
    }
}
