//
//  RoleMigration.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Fluent

extension Role {
    
    static var migrations: [AsyncMigration] {
        [CreateTable(), AddPermissions()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(Role.schema)
                .id()
                .field(FieldKeys.name.rawValue, .string, .required)
                .unique(on: FieldKeys.name.rawValue)
                .field(User.FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(User.FieldKeys.updatedAt.rawValue, .datetime, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(Role.schema).delete()
        }
    }
    
    struct AddPermissions: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(Role.schema)
                .field(FieldKeys.permissions.rawValue, .data)
                .update()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(Role.schema)
                .deleteField(FieldKeys.permissions.rawValue)
                .update()
        }
    }
}
