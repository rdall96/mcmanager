//
//  UserController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import Shared

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users").grouped(UserAuthenticator())
        users.get(use: all)
        users.get("profile", use: me)
        users.post(use: create)
        users.group(":userID") { user in
            user.get(use: self.user(req:))
            user.put(use: update)
            user.delete(use: delete)
        }
    }

    func all(req: Request) async throws -> [User] {
        try await User.query(on: req.db).all()
    }

    func create(req: Request) async throws -> User {
        // can only create if the authenticated user is an admin
        let authUser = try req.auth.require(User.self)
        guard authUser.isAdmin else {
            throw Abort(.forbidden)
        }
        
        let userRequest = try req.content.decode(User.self)
        // This new user will now need its password encrypted before saving
        let user = User(
            username: userRequest.username.lowercased(),
            password: try userRequest.hashPassword()
        )
        try await user.save(on: req.db)
        return user
    }
    
    func user(req: Request) async throws -> User {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db)
        else { throw Abort(.notFound) }
        return user
    }
    
    func me(req: Request) async throws -> User {
        try req.auth.require(User.self)
    }
    
    func update(req: Request) async throws -> User {
        let userRequest = try req.content.decode(User.self)
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db)
        else { throw Abort(.notFound) }
        
        // can only delete if the authenticated user is self or an admin
        let authUser = try req.auth.require(User.self)
        guard authUser.id == user.id || authUser.isAdmin else {
            throw Abort(.forbidden)
        }
        
        // password
        if !userRequest.password.isEmpty {
            user.password = try userRequest.hashPassword()
        }
        
        // update updatedAt time
        user.updatedAt = .now
        
        try await user.save(on: req.db)
        return user
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // can only delete if the authenticated user is self or an admin
        let authUser = try req.auth.require(User.self)
        guard authUser.id == user.id || authUser.isAdmin else {
            throw Abort(.forbidden)
        }
        
        try await user.delete(on: req.db)
        return .noContent
    }
}
