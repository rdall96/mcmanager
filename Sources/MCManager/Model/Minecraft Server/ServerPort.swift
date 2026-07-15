//
//  ServerPort.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/14/26.
//

import Foundation
import Vapor
import VaporToOpenAPI

extension MinecraftServer {
    /// Minecraft server port value.
    /// Automatically validates any interger value from the valid range of TCP/UDP ports.
    struct Port: RawRepresentable, Content {
        static let validPortRange: ClosedRange<Self> = 1024...65535

        let rawValue: UInt16

        init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - Equatable
extension MinecraftServer.Port: Equatable {
    static func == (lhs: MinecraftServer.Port, rhs: MinecraftServer.Port) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

// MARK: - Comparable
extension MinecraftServer.Port: Comparable {
    static func < (lhs: MinecraftServer.Port, rhs: MinecraftServer.Port) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Hashable
extension MinecraftServer.Port: Hashable {}

// MARK: - Codable
extension MinecraftServer.Port: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UInt16.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - ExpressibleByIntegerLiteral
extension MinecraftServer.Port: ExpressibleByIntegerLiteral {
    init(integerLiteral value: UInt16) {
        self.init(rawValue: value)
    }
}

extension MinecraftServer.Port: Strideable {
    typealias Stride = Int

    func distance(to other: Self) -> Stride {
        rawValue.distance(to: other.rawValue)
    }

    func advanced(by n: Stride) -> Self {
        let newValue = rawValue.advanced(by: n)
        return Self(rawValue: newValue)
    }
}

// MARK: - CustomStringConvertible
extension MinecraftServer.Port: CustomStringConvertible {
    var description: String { String(rawValue) }
}

// MARK: - LosslessStringConvertible
extension MinecraftServer.Port: LosslessStringConvertible {
    init?(_ description: String) {
        guard let value = UInt16(description) else {
            return nil
        }
        self.init(rawValue: value)
    }
}
