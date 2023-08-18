//
//  ServerMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
@_spi(MCManager_Server) import MCManager_Shared

extension Server {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(Server.schema)
                .id()
                .field(Server.FieldKeys.name.rawValue, .string, .required)
                .field(Server.FieldKeys.type.rawValue, .string, .required)
                .field(Server.FieldKeys.version.rawValue, .string, .required)
                .field(Server.FieldKeys.port.rawValue, .uint32, .required)
                .field(Server.FieldKeys.createdAt.rawValue, .datetime, .required)
                .field(Server.FieldKeys.updatedAt.rawValue, .datetime, .required)
                .ignoreExisting()
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Server.schema).delete()
        }
    }
}
