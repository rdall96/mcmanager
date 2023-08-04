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
        case userId = "user_id"
        case admin
        case issuedAt
        case expiresAt
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.subject.rawValue)
    var sub: SubjectClaim
    
    @Parent(key: FieldKeys.userId.rawValue)
    var user: User
    
    @Field(key: FieldKeys.admin.rawValue)
    var admin: Bool
    
    @Field(key: FieldKeys.issuedAt.rawValue)
    var iat: IssuedAtClaim
    
    @Field(key: FieldKeys.expiresAt.rawValue)
    var exp: ExpirationClaim
    
    init() {}
    
    init(
        id: UUID = UUID(),
        sub: SubjectClaim,
        userId: UUID,
        admin: Bool,
        iat: IssuedAtClaim,
        exp: ExpirationClaim
    ) {
        self.id = id
        self.sub = sub
        self.$user.id = userId
        self.admin = admin
        self.iat = iat
        self.exp = exp
    }
}

extension SessionToken {
    /// Create a new token for the given user
    static func token(for user: User) -> SessionToken? {
        guard let userId = user.id else { return nil }
        let currentDate: Date = .now
        let expirationDate = Self.accessExpiration(for: currentDate)
        return .init(
            sub: .init(value: "mcmanager"),
            userId: userId,
            admin: user.isAdmin,
            iat: .init(value: currentDate),
            exp: .init(value: expirationDate)
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
        lhs.user.id == rhs.user.id &&
        lhs.iat.value == rhs.iat.value &&
        lhs.exp.value == rhs.exp.value
    }
}

// MARK: - Authenticatable
extension SessionToken: Authenticatable {}

// MARK: - JWTPayload
extension SessionToken: JWTPayload {
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}
