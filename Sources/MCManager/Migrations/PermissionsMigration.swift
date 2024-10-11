//
//  PermissionsMigration.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/11/24.
//

import Fluent

extension Permissions {
    
    static var migrations: [AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(Permissions.schema)
                .id()
                .field(FieldKeys.isDefaults.rawValue, .bool, .sql(.default(false)))
                .field(FieldKeys.application.rawValue, .uint64, .required)
                .field(FieldKeys.users.rawValue, .uint64, .required)
                .field(FieldKeys.servers.rawValue, .uint64, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(Permissions.schema).delete()
        }
    }
}
