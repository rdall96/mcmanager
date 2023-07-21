//
//  ServerStatusCacheMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/21/23.
//

import Fluent

extension ServerStatusCache {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(ServerStatusCache.schema)
                .id()
                .field(ServerStatusCache.FieldKeys.expiresAt.rawValue, .datetime, .required)
                .field(ServerStatusCache.FieldKeys.data.rawValue, .string, .required)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ServerStatusCache.schema).delete()
        }
    }
}
