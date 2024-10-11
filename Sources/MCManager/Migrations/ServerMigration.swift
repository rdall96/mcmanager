//
//  ServerMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent

extension MCServer {
    
    static var migrations: [AsyncMigration] {
        [CreateTable()]
    }
    
    struct CreateTable: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(MCServer.schema)
                .id()
                .field(FieldKeys.name.rawValue, .string, .required)
                .unique(on: FieldKeys.name.rawValue)
                .field(FieldKeys.type.rawValue, .string, .required)
                .field(FieldKeys.version.rawValue, .string, .required)
                .field(FieldKeys.port.rawValue, .uint32, .required)
                .field(FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(FieldKeys.updatedAt.rawValue, .datetime, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(MCServer.schema).delete()
        }
    }
}
