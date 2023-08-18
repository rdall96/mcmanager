//
//  ServerConfig.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    /// Represents a single server config value (aka: server property)
    public struct Config: Hashable, Identifiable {
        public let id: String
        public var value: Value
        
        @_spi(MCManager_Tests)
        @_spi(MinecraftRuntime)
        public init(_ id: String, value: Value) {
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

extension Server.Config: Codable {}

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
