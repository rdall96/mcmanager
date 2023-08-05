//
//  AuthenticationController.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import MCManager_Shared

struct AuthenticationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes
            .grouped(User.asyncCredentialsAuthenticator())
            .grouped(User.guardMiddleware())
            .post("login", use: login)
        
        routes
            .grouped(SessionToken.Authenticator())
            .grouped(User.guardMiddleware())
            .get("logout", use: logout)
    }
    
    /// Login request
    func login(req: Request) async throws -> ClientSession {
        let user = try req.auth.require(User.self)
        guard let payload = SessionToken.token(for: user) else {
            throw Abort(.unauthorized)
        }
        try await payload.save(on: req.db)
        let token = try req.jwt.sign(payload)
        return .init(accessToken: token)
    }
    
    /// Logout the current session
    func logout(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        // delete any existing session for this user
        let sessionTokens = try await SessionToken.query(on: req.db)
            .filter(\.$user.$id, .equal, try user.requireID())
            .all()
        for sessionToken in sessionTokens {
            try await sessionToken.delete(on: req.db)
        }
        // logout
        req.auth.logout(User.self)
        return .noContent
    }
}
