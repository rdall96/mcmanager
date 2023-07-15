//
//  UserMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Shared

extension User {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(User.schema)
                .id()
                .field(User.FieldKeys.username.rawValue, .string, .required)
                .unique(on: User.FieldKeys.username.rawValue)
                .field(User.FieldKeys.password.rawValue, .string, .required)
                .field(User.FieldKeys.created_at.rawValue, .datetime, .required)
                .field(User.FieldKeys.updated_at.rawValue, .datetime, .required)
                .field(User.FieldKeys.is_admin.rawValue, .bool, .required)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
}
