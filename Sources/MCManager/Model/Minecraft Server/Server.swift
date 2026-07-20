//
//  Server.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Foundation
import Fluent
import Vapor
import VaporToOpenAPI

/// Minecraft server metadata.
final class MinecraftServer: Model, Content, @unchecked Sendable {

    static let schema = "servers"
    
    enum FieldKeys: FieldKey {
        case name
        case type
        case version
        case port
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }
    
    @ID(key: .id)
    /// Server ID.
    var id: UUID?
    
    @Field(key: FieldKeys.name.rawValue)
    /// Server name.
    var name: String
    
    @Field(key: FieldKeys.type.rawValue)
    /// Server type.
    var type: ServerType
    
    @Field(key: FieldKeys.version.rawValue)
    /// Game version.
    var version: Version
    
    @Field(key: FieldKeys.port.rawValue)
    /// Network port the server runs on.
    var port: Port

    @Field(key: FieldKeys.createdAt.rawValue)
    /// Date when the server was created.
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    /// Date when the server was last updated.
    var updatedAt: Date
    
    init() {}
    
    init(
        id: UUID = UUID(),
        name: String,
        type: ServerType,
        version: Version,
        port: Port
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.version = version
        self.port = port
        self.createdAt = .now
        self.updatedAt = .now
    }
    
    // MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case version
        case port
        case createdAt
        case updatedAt
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(ServerType.self, forKey: .type)
        self.version = try container.decode(Version.self, forKey: .version)
        self.port = try container.decode(Port.self, forKey: .port)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // Custom encode(to:) method.
    // Nothing changes here from the default, but Fluent does things differently under the hood (Mirror reflection)
    // which tricks VaporToOpenAPI in reporting the wrong data schema.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(version, forKey: .version)
        try container.encode(port, forKey: .port)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Open API Spec
extension MinecraftServer: OpenAPIDescriptable {
    static var openAPIDescription: (any OpenAPIDescriptionType)? {
        OpenAPIDescription<CodingKeys>("Minecraft server metadata.")
            .add(for: .id, "Server ID.")
            .add(for: .name, "Server name.")
            .add(for: .type, "Server type.")
            .add(for: .version, "Game version.")
            .add(for: .port, "Network port the server runs on.")
            .add(for: .createdAt, "Date when the server was created.")
            .add(for: .updatedAt, "Date when the server was last updated.")
    }
}
