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
        func prepare(on database: Database) async throws {
            try await database.schema(MCServer.schema)
                .id()
                .field(MCServer.FieldKeys.name.rawValue, .string, .required)
                .field(MCServer.FieldKeys.type.rawValue, .string, .required)
                .field(MCServer.FieldKeys.version.rawValue, .string, .required)
                .field(MCServer.FieldKeys.port.rawValue, .uint32, .required)
                .field(MCServer.FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(MCServer.FieldKeys.updatedAt.rawValue, .datetime, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(MCServer.schema).delete()
        }
    }
}
