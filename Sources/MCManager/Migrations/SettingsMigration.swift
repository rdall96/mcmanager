//
//  SettingsMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent

extension Settings {
    
    static var migrations: [AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(Settings.schema)
                .id()
                .field(Settings.FieldKeys.serverStatusCacheTTLSeconds.rawValue, .uint, .required)
                .field(Settings.FieldKeys.allowedServerPorts.rawValue, .string, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Settings.schema).delete()
        }
    }
}
