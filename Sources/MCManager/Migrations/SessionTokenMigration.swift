//
//  SessionTokenMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent

extension SessionToken {
    
    static var migrations: [AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(SessionToken.schema)
                .id()
                .field(SessionToken.FieldKeys.subject.rawValue, .string, .required)
                .field(SessionToken.FieldKeys.issuedAt.rawValue, .datetime, .required)
                .field(SessionToken.FieldKeys.expiresAt.rawValue, .datetime, .required)
                .field(SessionToken.FieldKeys.userId.rawValue, .uuid, .references("users", "id"))
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(SessionToken.schema).delete()
        }
    }
}
