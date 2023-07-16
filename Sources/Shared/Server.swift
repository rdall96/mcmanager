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
    public var version: String
    
    @Field(key: FieldKeys.port.rawValue)
    public var port: UInt32
    
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
        version: String,
        port: UInt32
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
        version: String,
        port: UInt32
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
            type: try container.decodeIfPresent(ServerType.self, forKey: .type) ?? .java,
            version: try container.decodeIfPresent(String.self, forKey: .version) ?? "",
            port: try container.decodeIfPresent(UInt32.self, forKey: .port) ?? 0
        )
    }
}

// MARK: - Status
extension Server {
    public enum Status: String, Codable, CaseIterable {
        case unknown
        case stopped
        case starting
        case running
        case stopping
        case error
    }
}

// MARK: - ServerType
extension Server {
    public enum ServerType: String, Codable, CaseIterable {
        case java
        case javaFabric = "java_fabric"
        case javaForge = "java_forge"
        case bedrock
    }
}

// MARK: - Info
extension Server {
    public struct Info: Codable {
        public let status: Status
        /// Number of active players on the server
        public let onlinePlayerCount: Int?
        /// CPU usage for the server process
        public let cpuUsage: Double?
        /// Memory usage (bytes) for the server process
        public let memoryUsageBytes: Int?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .unknown
            onlinePlayerCount = try? container.decode(Int.self, forKey: .onlinePlayerCount)
            cpuUsage = try? container.decode(Double.self, forKey: .cpuUsage)
            memoryUsageBytes = try? container.decode(Int.self, forKey: .memoryUsageBytes)
        }
        
        enum CodingKeys: String, CodingKey {
            case status
            case onlinePlayerCount = "online_players"
            case cpuUsage = "cpu_usage"
            case memoryUsageBytes = "memory_usage"
        }
        
    }
}

// MARK: - BuilderInfo
extension Server {
    /**
     Data regarding the types and game versions that can be used to create a server.
     This should be used a reference before calling `createServer`.
     */
    public struct BuilderInfo: Codable {
        public let type: ServerType
        public let versions: [String]
    }
}

// MARK: - Properties
extension Server {
    /// Represents the actual value of any server property since it can be of any primitive type
    public enum PropertyValue: Codable {
        
        case flag(Bool), number(Int), text(String)
        
        public init(from decoder: Decoder) throws {
            if let bool = try? decoder.singleValueContainer().decode(Bool.self) {
                self = .flag(bool)
            }
            else if let int = try? decoder.singleValueContainer().decode(Int.self) {
                self = .number(int)
            }
            else {
                self = .text(
                    try? decoder.singleValueContainer().decode(String.self) ?? ""
                )
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .flag(let bool): try container.encode(bool)
            case .number(let int): try container.encode(int)
            case .text(let string): try container.encode(string)
            }
        }
        
        /// A textual representation of the underlying value
        public var description: String {
            switch self {
            case .flag(let bool): return bool.description
            case .number(let int): return int.description
            case .text(let string): return string
            }
        }
    }
}
