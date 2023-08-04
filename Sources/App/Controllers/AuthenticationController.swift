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
        let auth = routes.grouped(User.asyncCredentialsAuthenticator(), User.guardMiddleware())
        auth.post("login", use: login)
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
    
    /// Refresh authentication token
    func refresh(req: Request) async throws -> ClientSession {
        throw Abort(.notImplemented)
    }
}
