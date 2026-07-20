//
//  RoleMigration.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Fluent

extension Role {
    
    static var migrations: [any AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(Role.schema)
                .id()
                .field(FieldKeys.name.rawValue, .string, .required)
                .unique(on: FieldKeys.name.rawValue, name: "no_duplicate_\(FieldKeys.name.rawValue)")
                .field(FieldKeys.permissionsID.rawValue, .uuid, .references(Permissions.schema, .id))
                .field(FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(FieldKeys.updatedAt.rawValue, .datetime, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(Role.schema).delete()
        }
    }
}
