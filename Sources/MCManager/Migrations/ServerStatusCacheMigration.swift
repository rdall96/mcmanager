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
        func prepare(on database: any Database) async throws {
            try await database.schema(ServerStatusCache.schema)
                .id()
                .field(FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(FieldKeys.infoData.rawValue, .data, .required)
                .field(FieldKeys.statsData.rawValue, .data, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(ServerStatusCache.schema).delete()
        }
    }
}
