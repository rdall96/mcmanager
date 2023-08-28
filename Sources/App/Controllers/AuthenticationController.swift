//
//  AuthenticationController.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import MCManager_Shared

struct AuthenticationController: MCManagerAPIRoute, RouteCollection {
    let logger: Logger
    
    func boot(routes: RoutesBuilder) throws {
        routes
            .grouped(User.asyncCredentialsAuthenticator())
            .grouped(User.guardMiddleware())
            .post("login", use: login)
        
        routes
            .grouped(SessionToken.Authenticator())
            .grouped(User.guardMiddleware())
            .get("logout", use: logout)
        
        routes.get("key", use: publicKey)
    }
    
    /// Login request
    func login(req: Request) async throws -> ClientSession {
        let user = try req.auth.require(User.self)
        guard let payload = try SessionToken.token(for: user) else {
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
    
    /// Public key to verify token signature
    func publicKey(req: Request) async throws -> String {
        do {
            let keyPath = try DirectoryConfiguration.detect().publicKeyPath
            let keyComponents = try String(contentsOf: keyPath).split(separator: " ")
                .compactMap({ String($0) })
            // the key structure will be something like: ssh-rsa AAAAB3...
            // where the first string is the type, the second the actual key,
            // and optionally there will be a third component with the user and hostname of the shell that generated it
            guard keyComponents.count > 1 else {
                throw Abort(.custom(code: 500, reasonPhrase: "Corrupted public key data"))
            }
            // we only care about the key component
            return keyComponents[1]
        }
        catch {
            logger.error("Failed to get local public signing key: \(error)")
            throw Abort(.internalServerError)
        }
    }
}
