//
//  SettingsMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent

extension Settings {
    
    static var migrations: [AsyncMigration] {
        [CreateTable(), MigrateToV2()]
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
    
    struct MigrateToV2: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(Settings.schema)
                .field(
                    Settings.FieldKeys.maxRunningServers.rawValue,
                    .uint,
                    .required,
                    .sql(.default(Settings.defaults.maxRunningServers))
                )
                .update()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(Settings.schema)
                .deleteField(Settings.FieldKeys.maxRunningServers.rawValue)
                .update()
        }
    }
}
