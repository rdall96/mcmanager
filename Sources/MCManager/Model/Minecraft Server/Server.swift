//
//  Server.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Foundation
import Fluent
import Vapor

final class MCServer: Model, Content {
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
    var id: UUID?
    
    @Field(key: FieldKeys.name.rawValue)
    var name: String
    
    @Field(key: FieldKeys.type.rawValue)
    var type: ServerType
    
    @Field(key: FieldKeys.version.rawValue)
    var version: Version
    
    @Field(key: FieldKeys.port.rawValue)
    var port: UInt16
    
    @Field(key: FieldKeys.createdAt.rawValue)
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    var updatedAt: Date
    
    init() {}
    
    init(
        id: UUID,
        name: String,
        type: ServerType,
        version: Version,
        port: UInt16
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.version = version
        self.port = port
        self.createdAt = .now
        self.updatedAt = .now
    }
    
    convenience init(
        name: String,
        type: ServerType,
        version: Version,
        port: UInt16
    ) {
        self.init(
            id: UUID(),
            name: name,
            type: type,
            version: version,
            port: port
        )
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case version
        case port
        case createdAt
        case updatedAt
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // this method is called when we read the data from an API call, so we assign defaults to allow for partial updates
        self.init(
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "A Minecraft Server",
            type: try container.decodeIfPresent(ServerType.self, forKey: .type) ?? .java,
            version: try container.decodeIfPresent(Version.self, forKey: .version) ?? .none,
            port: try container.decodeIfPresent(UInt16.self, forKey: .port) ?? 25565
        )
    }
}
