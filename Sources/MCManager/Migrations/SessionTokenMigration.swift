//
//  SessionTokenMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent

extension SessionToken {
    
    static var migrations: [any AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(SessionToken.schema)
                .id()
                .field(FieldKeys.subject.rawValue, .string, .required)
                .field(FieldKeys.issuedAt.rawValue, .datetime, .required)
                .field(FieldKeys.expiresAt.rawValue, .datetime, .required)
                .field(FieldKeys.userId.rawValue, .uuid, .references(User.schema, .id))
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(SessionToken.schema).delete()
        }
    }
}
