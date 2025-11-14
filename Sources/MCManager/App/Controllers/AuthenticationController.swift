//
//  AuthenticationController.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor

struct AuthenticationController: MCManagerAPIRoute, RouteCollection {
    let logger = Logger(label: "mcmanager.auth")
    
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        auth
            .requireUserCredentials()
            .post("login", use: login)
        
        auth
            .requireAuthentication()
            .get("logout", use: logout)
        
        auth.get("key", use: publicKey)
    }
    
    /// Login request
    func login(req: Request) async throws -> ClientSession {
        let user = try requireAuthenticated(for: req)
        guard let payload = try SessionToken.token(for: user) else {
            throw AuthenticationError.invalidCredentials
        }
        try await payload.save(on: req.db)
        let token = try req.jwt.sign(payload)
        return .init(accessToken: token)
    }
    
    /// Logout the current session
    func logout(req: Request) async throws -> HTTPStatus {
        let user = try requireAuthenticated(for: req)
        // delete any existing session for this user
        try await SessionToken.query(on: req.db)
            .filter(\.$user.$id, .equal, try user.requireID())
            .all()
            .delete(on: req.db)
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
                logger.critical("Corrupted public key data")
                throw Abort(.internalServerError)
            }
            // we only care about the key component
            return keyComponents[1]
        }
        catch {
            logger.error("Failed to get local public signing key: \(error)")
            throw Abort(.internalServerError, reason: "Invalid signing key!")
        }
    }
}
