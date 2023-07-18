//
//  Server.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Foundation
import Fluent

// MARK: - Server
public final class Server: Model {
    @_spi(MCManager_Server)
    public static let schema = "servers"
    
    @_spi(MCManager_Server)
    public enum FieldKeys: FieldKey {
        case name
        case type
        case version
        case port
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: FieldKeys.name.rawValue)
    public var name: String
    
    @Field(key: FieldKeys.type.rawValue)
    public var type: ServerType
    
    @Field(key: FieldKeys.version.rawValue)
    public var version: Server.Version
    
    @Field(key: FieldKeys.port.rawValue)
    public var port: UInt16
    
    @Field(key: FieldKeys.createdAt.rawValue)
    public var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    public var updatedAt: Date
    
    public init() {}
    
    @_spi(MCManager_Server)
    public init(
        id: UUID,
        name: String,
        type: ServerType,
        version: Server.Version,
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
    
    public convenience init(
        name: String,
        type: ServerType,
        version: Server.Version,
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
}

extension Server: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case version
        case port
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // this method is called when we read the data from an API call, so we assign defaults to allow for partial updates
        self.init(
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
            type: try container.decodeIfPresent(ServerType.self, forKey: .type) ?? .unknown,
            version: try container.decodeIfPresent(Server.Version.self, forKey: .version) ?? .none,
            port: try container.decodeIfPresent(UInt16.self, forKey: .port) ?? 0
        )
    }
}
