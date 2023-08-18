//
//  SettingsMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent
@_spi(MCManager_Server) import MCManager_Shared

extension Settings {
    struct Migration: AsyncMigration {
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
