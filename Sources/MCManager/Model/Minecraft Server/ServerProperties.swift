//
//  ServerProperties.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor

extension MCServer {
    struct Properties: Codable, Content {
        typealias Key = String
        
        private(set) var data: [Key : Value]
        
        init(_ data: [Key : Value]) {
            self.data = data
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let data = try container.decode([Key : Value].self)
            self.init(data)
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(data)
        }
        
        var count: Int { data.keys.count }
        
        func contains(_ key: Key) -> Bool {
            data.keys.contains(key)
        }
        
        func value(forKey key: Key) -> Value? {
            data[key]
        }
        
        mutating func updateValue(_ value: Value, forKey key: Key) {
            self.data.updateValue(value, forKey: key)
        }
    }
}

extension MCServer.Properties {
    /// Represents the actual value of any server property since it can be of any primitive type
    enum Value: Codable, Hashable {
        
        case flag(Bool)
        case number(Int)
        case text(String)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let bool = try? container.decode(Bool.self) {
                self = .flag(bool)
            }
            else if let int = try? container.decode(Int.self) {
                self = .number(int)
            }
            else {
                let string = try? container.decode(String.self)
                self = .text(string ?? "")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .flag(let bool): try container.encode(bool)
            case .number(let int): try container.encode(int)
            case .text(let string): try container.encode(string)
            }
        }
        
        /// A textual representation of the underlying value
        var description: String {
            switch self {
            case .flag(let bool): return bool.description.lowercased()
            case .number(let int): return int.description
            case .text(let string): return string
            }
        }
    }
}
