//
//  UserMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
@_spi(MCManager_Server) import MCManager_Shared

extension User {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(User.schema)
                .id()
                .field(User.FieldKeys.username.rawValue, .string, .required)
                .unique(on: User.FieldKeys.username.rawValue)
                .field(User.FieldKeys.password.rawValue, .string, .required)
                .field(User.FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(User.FieldKeys.updatedAt.rawValue, .datetime, .required)
                .field(User.FieldKeys.isAdmin.rawValue, .bool, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
}
