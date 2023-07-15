//
//  ServerMigration.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Shared

extension Server {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(Server.schema)
                .id()
                .field("name", .string, .required)
                .field("type", .string, .required)
                .field("version", .string, .required)
                .field("port", .uint32, .required)
                .field("created_at", .datetime, .required)
                .field("updated_at", .datetime, .required)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Server.schema).delete()
        }
    }
}
