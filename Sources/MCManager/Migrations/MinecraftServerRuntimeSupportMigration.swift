//
//  MinecraftServerRuntimeSupportMigration.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 11/8/25.
//

import Fluent

extension ServerRuntimeSupportCache {

    static var migrations: [AsyncMigration] {
        [CreateTable()]
    }

    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(ServerRuntimeSupportCache.schema)
                .id()
                .field(FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(FieldKeys.serverType.rawValue, .string, .required)
                .unique(on: FieldKeys.serverType.rawValue, name: "no_duplicate_\(FieldKeys.serverType.rawValue)")
                .field(FieldKeys.versions.rawValue, .array(of: .string))
                .ignoreExisting()
                .create()
        }

        func revert(on database: any Database) async throws {
            try await database.schema(ServerRuntimeSupportCache.schema).delete()
        }
    }
}
