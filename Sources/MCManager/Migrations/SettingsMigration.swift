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
                .field(FieldKeys.serverStatusCacheTTLSeconds.rawValue, .uint, .required)
                .field(FieldKeys.allowedServerPorts.rawValue, .string, .required)
                .field(FieldKeys.maxRunningServers.rawValue, .uint, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Settings.schema).delete()
        }
    }
}
