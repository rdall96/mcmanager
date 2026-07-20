//
//  AuthenticationController.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import JWT
import Vapor

struct AuthenticationController: MCManagerAPIRoute, RouteCollection {
    let logger = Logger(label: "mcmanager.auth")
    
    func boot(routes: any RoutesBuilder) throws {
        let authRoutes = routes.grouped("auth")
            .openAPIMetadata(tags: .auth)

        // Login
        authRoutes.requireUserCredentials()
            .post("login", use: login)
            .openAPIMetadata(
                summary: "Authenticate a user",
                request: .userCredentialsRequest,
                responses: .authenticationSuccessfulResponse, .invalidCredentialsResponse
            )

        // Logout
        authRoutes.requireAuthentication()
            .get("logout", use: logout)
            .openAPIMetadata(
                summary: "Log out the current user",
                request: .requiresAuthentication,
                responses: .emptyResponse, .notAuthenticatedResponse
            )

        // Public key
        authRoutes.get("key", use: publicKey)
            .openAPIMetadata(
                summary: "Fetch the public key used to validate authentication tokens",
                responses: .publicKeyResponse
            )
    }
    
    /// Authenticate a user.
    func login(req: Request) async throws -> ClientSession {
        let user = try requireAuthenticated(for: req)
        guard let payload = try SessionToken.token(for: user) else {
            throw AuthenticationError.invalidCredentials
        }
        try await payload.save(on: req.db)
        let token = try await req.jwt.sign(payload)
        return ClientSession(accessToken: token)
    }
    
    /// Log out the current user.
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
    
    /// Fetch the public key used to validate authentication tokens.
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
