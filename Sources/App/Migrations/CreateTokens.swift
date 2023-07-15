//
//  CreateTokens.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent

extension SessionToken {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(SessionToken.schema)
                .id()
                .field("sub", .string, .required)
                .field("user_id", .uuid, .references("users", "id"))
                .field("admin", .bool, .required)
                .field("iat", .datetime, .required)
                .field("exp", .datetime, .required)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(SessionToken.schema).delete()
        }
    }
}
