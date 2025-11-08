//
//  SettingsMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent

extension Settings {
    
    static var migrations: [AsyncMigration] {
        [
            CreateTable(),
            AddServerSupportCacheTTLField()
        ]
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

    struct AddServerSupportCacheTTLField: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(Settings.schema)
                .field(
                    FieldKeys.serverSupportCacheTTLSeconds.rawValue,
                    .uint,
                    .required,
                    .sql(.default(Settings.defaults.serverSupportCacheTTLSeconds))
                )
                .ignoreExisting()
                .update()
        }

        func revert(on database: any Database) async throws {
            try await database.schema(Settings.schema)
                .deleteField(FieldKeys.serverSupportCacheTTLSeconds.rawValue)
                .update()
        }
    }
}
