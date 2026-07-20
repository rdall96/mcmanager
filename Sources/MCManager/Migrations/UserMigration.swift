//
//  UserMigration.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent

extension User {
    
    static var migrations: [any AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(User.schema)
                .id()
                .field(FieldKeys.username.rawValue, .string, .required)
                .unique(on: FieldKeys.username.rawValue, name: "no_duplicate_\(FieldKeys.username.rawValue)")
                .field(FieldKeys.password.rawValue, .string, .required)
                .field(FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(FieldKeys.updatedAt.rawValue, .datetime, .required)
                .field(FieldKeys.adminPrivileges.rawValue, .uint8, .required)
                .field(FieldKeys.roleID.rawValue, .uuid, .references(Role.schema, .id))
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
}
