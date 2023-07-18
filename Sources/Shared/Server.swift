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
        version: String,
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
        version: String,
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
            type: try container.decodeIfPresent(ServerType.self, forKey: .type) ?? .java,
            version: try container.decodeIfPresent(String.self, forKey: .version) ?? "",
            port: try container.decodeIfPresent(UInt16.self, forKey: .port) ?? 0
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
        public let onlinePlayerCount: UInt?
        /// CPU usage for the server process
        public let cpuUsage: UInt64
        /// Memory usage (bytes) for the server process
        public let memoryUsageBytes: UInt64
        
        @_spi(MCManager_Runtime)
        public init(
            status: Status,
            onlinePlayerCount: UInt = 0,
            cpuUsage: UInt64 = 0,
            memoryUsage: UInt64 = 0
        ) {
            self.status = status
            self.onlinePlayerCount = onlinePlayerCount
            self.cpuUsage = cpuUsage
            self.memoryUsageBytes = memoryUsage
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .unknown
            onlinePlayerCount = try? container.decode(UInt.self, forKey: .onlinePlayerCount)
            cpuUsage = try container.decode(UInt64.self, forKey: .cpuUsage)
            memoryUsageBytes = try container.decode(UInt64.self, forKey: .memoryUsageBytes)
        }
        
        enum CodingKeys: String, CodingKey {
            case status
            case onlinePlayerCount = "online_players"
            case cpuUsage = "cpu_usage"
            case memoryUsageBytes = "memory_usage"
        }
        
    }
}

// MARK: - Supported Runtimes
extension Server {
    /**
     Data regarding the types and game versions that can be used to create a server.
     This should be used a reference before calling `createServer`.
     */
    public struct RuntimeSupport: Codable {
        public let type: ServerType
        public let versions: [String]
        
        @_spi(MCManager_Runtime)
        public init(type: ServerType, versions: [String]) {
            self.type = type
            self.versions = versions
        }
    }
}

// MARK: - Properties
extension Server {
    /// Represents a single server config value (aka: server property)
    public struct Config: Codable, Hashable, Identifiable {
        public let id: String
        public var value: Value
        
        @_spi(MCManager_Tests)
        public init(id: String, value: Value) {
            self.id = id
            self.value = value
        }
        
        public static func == (lhs: Server.Config, rhs: Server.Config) -> Bool {
            // we only check the id since two objects with the same name cannot exist in the same list,
            // and therefore they should override each other
            lhs.id == rhs.id
        }
    }
}

extension Server.Config {
    /// Represents the actual value of any server property since it can be of any primitive type
    public enum Value: Codable, Hashable {
        
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
                    (try? decoder.singleValueContainer().decode(String.self)) ?? ""
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
            case .flag(let bool): return bool.description.lowercased()
            case .number(let int): return int.description
            case .text(let string): return string
            }
        }
    }
}
