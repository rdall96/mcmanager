//
//  SessionToken.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import JWT
import Vapor
import MCManager_Shared

final class SessionToken: Model, Content {
    static let schema = "tokens"

    enum FieldKeys: FieldKey {
        case subject
        case issuedAt
        case expiresAt
        case userId = "user_id"
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.subject.rawValue)
    var sub: SubjectClaim
    
    @Field(key: FieldKeys.issuedAt.rawValue)
    var iat: IssuedAtClaim
    
    @Field(key: FieldKeys.expiresAt.rawValue)
    var exp: ExpirationClaim
    
    @Parent(key: FieldKeys.userId.rawValue)
    var user: User
    private var userStorage: User?
    
    init() {}
    
    init(
        id: UUID = UUID(),
        sub: SubjectClaim,
        iat: IssuedAtClaim,
        exp: ExpirationClaim,
        user: User
    ) throws {
        self.id = id
        self.sub = sub
        self.iat = iat
        self.exp = exp
        self.$user.id = try user.requireID()
        self.userStorage = user
    }
}

extension SessionToken {
    /// Create a new token for the given user
    static func token(for user: User, database: Database? = nil) throws -> SessionToken? {
        let currentDate: Date = .now
        let expirationDate = Self.accessExpiration(for: currentDate)
        return try .init(
            sub: .init(value: "mcmanager"),
            iat: .init(value: currentDate),
            exp: .init(value: expirationDate),
            user: user
        )
    }
}

// MARK: - Constants
extension SessionToken {
    
    /// Access token duration (default: 24H)
    static var accessTokenTTL: TimeInterval {
        1 * 24 * 60 * 60 // 1 day (24 hours)
    }
    
    /// Calculate the expiration date
    static func accessExpiration(for referenceDate: Date) -> Date {
        referenceDate.addingTimeInterval(accessTokenTTL)
    }
}

// MARK: - Equatable
extension SessionToken: Equatable {
    static func == (lhs: SessionToken, rhs: SessionToken) -> Bool {
        lhs.id == rhs.id &&
        lhs.$user.id == rhs.$user.id &&
        lhs.iat.value == rhs.iat.value &&
        lhs.exp.value == rhs.exp.value
    }
}

// MARK: - Authenticatable
extension SessionToken: Authenticatable {}

// MARK: - JWTPayload
extension SessionToken: JWTPayload {
    func verify(using signer: JWTSigner) throws {
        // ensure the JWT is not expired
        try exp.verifyNotExpired()
    }
}

// MARK: - AsyncBearerAuthenticator
extension SessionToken {
    struct Authenticator: AsyncBearerAuthenticator {
        func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
            // ensure it's the right type of jwt (this will also ensure it's signed correctly)
            let jwt = try request.jwt.verify(as: SessionToken.self)
            // ensure this token exists on the database
            let storedJwt = try await SessionToken.find(jwt.id, on: request.db)
            guard let storedJwt, try storedJwt.requireID() == jwt.id else {
                throw Abort(.unauthorized)
            }
            let user = try await storedJwt.$user.get(on: request.db)
            request.auth.login(user)
        }
    }
}

 // MARK: - Codable
extension SessionToken: Encodable {
    private enum Keys: String, CodingKey {
        case id
        case sub
        case user
        case iat
        case exp
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sub, forKey: .sub)
        try container.encode(userStorage, forKey: .user)
        try container.encode(iat, forKey: .iat)
        try container.encode(exp, forKey: .exp)
    }
}
