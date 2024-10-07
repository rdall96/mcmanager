//
//  ServerStatusCacheMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/21/23.
//

import Fluent

extension ServerStatusCache {
    
    static var migrations: [AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(ServerStatusCache.schema)
                .id()
                .field(ServerStatusCache.FieldKeys.expiresAt.rawValue, .datetime, .required)
                .field(ServerStatusCache.FieldKeys.infoData.rawValue, .data, .required)
                .field(ServerStatusCache.FieldKeys.statsData.rawValue, .data, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ServerStatusCache.schema).delete()
        }
    }
}
