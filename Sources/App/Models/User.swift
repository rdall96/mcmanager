//
//  User.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
@_spi(MCManager_Server) import Shared

extension User: Content {}

extension User: ModelCredentialsAuthenticatable {
    public static let usernameKey: KeyPath<User, Field<String>> = \User.$username
    public static let passwordHashKey: KeyPath<User, Field<String>> = \User.$password
    
    public func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

struct UserAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let jwt = try request.jwt.verify(bearer.token, as: SessionToken.self)
        if try await SessionToken.find(jwt.id, on: request.db) == jwt {
            request.auth.login(jwt.user)
        }
        else {
            throw Abort(.unauthorized)
        }
    }
}

// MARK: Password hashing
extension User {
    /// Hash the password
    func hashPassword() throws -> String {
        try Bcrypt.hash(password)
    }
}

// MARK: - Default user (admin)
extension User {
    static var admin: User {
        let user = User(
            id: UUID(uuidString: "7a3a593c-8fd0-4906-a11b-6a8054cf4ac9")!,
            username: "admin",
            password: "mcmanager",
            isAdmin: true
        )
        if let hashedPassword = try? user.hashPassword() {
            user.password = hashedPassword
        }
        return user
    }
}
