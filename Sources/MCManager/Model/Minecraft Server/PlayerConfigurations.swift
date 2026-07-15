//
//  PlayerConfigurations.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/12/26.
//

import Foundation
import Vapor
import VaporToOpenAPI

protocol MinecraftServerPlayerConfiguration: Identifiable, Equatable, Hashable, Content, Codable {
    // always requires a player id (optional for legacy purposes) and name
    var id: UUID? { get }
    var name: String { get }

    // required initializer to create a player configuration from player info
    init(_ player: MinecraftPlayerInfo)
}

extension MinecraftServer {

    @OpenAPIDescriptable
    /// A Minecraft server operator configuration.
    struct Operator: MinecraftServerPlayerConfiguration {

        /// Player ID.
        let id: UUID?

        /// Player name.
        let name: String

        /// Admin permission level.
        /// Levels were included in Minecraft 1.14.4. Prior to that version, all operators had the same permissions (all).
        /// Known levels at the time of writing this (latest game version: 26.2).
        /// * Level 1 - (moderator) Player can bypass spawn protection.
        /// * Level 2 - (gamemaster) Player or executor can use more commands and player can use command blocks.
        /// * Level 3 - (admin) Player or executor can use commands related to multiplayer management.
        /// * Level 4 - (owner) Player or executor can use all of the commands, including commands related to server management.
        typealias Level = UInt

        /// The level of operator permissions for this user.
        let level: Level?

        /// Allows player to bypass server player limit.
        let ignoresPlayerLimit: Bool?

        init(id: UUID? = nil, name: String, level: UInt, ignoresPlayerLimit: Bool? = nil) {
            self.id = id
            self.name = name
            self.level = level
            self.ignoresPlayerLimit = ignoresPlayerLimit ?? false
        }

        init(_ player: MinecraftPlayerInfo) {
            self.id = player.id
            self.name = player.name
            self.level = nil
            self.ignoresPlayerLimit = false
        }

        enum CodingKeys: String, CodingKey {
            case id = "uuid"
            case name
            case level
            case ignoresPlayerLimit = "bypassesPlayerLimit"
        }

        static func == (lhs: Operator, rhs: Operator) -> Bool {
            // equal if same id or same name, level and other properties can be overwritten
            if let lhsID = lhs.id, let rhsID = rhs.id {
                return lhsID == rhsID
            }
            else {
                return lhs.name == rhs.name
            }
        }
    }

    /// Minecraft server operators list.
    typealias Operators = Set<Operator>

    @OpenAPIDescriptable
    /// Minecraft user that is allowed to join the server.
    struct WhitelistedPlayer: MinecraftServerPlayerConfiguration {

        /// Player ID.
        let id: UUID?
        /// Player name.
        let name: String

        init(id: UUID? = nil, name: String) {
            self.id = id
            self.name = name
        }

        init(_ player: MinecraftPlayerInfo) {
            self.init(id: player.id, name: player.name)
        }

        enum CodingKeys: String, CodingKey {
            case id = "uuid"
            case name
        }

        static func == (lhs: WhitelistedPlayer, rhs: WhitelistedPlayer) -> Bool {
            // equal if same id or same name
            if let lhsID = lhs.id, let rhsID = rhs.id {
                return lhsID == rhsID
            }
            else {
                return lhs.name == rhs.name
            }
        }
    }

    /// Minecraft server whitelist.
    typealias Whitelist = Set<WhitelistedPlayer>

    @OpenAPIDescriptable
    /// Minecraft user that is banned from the server.
    struct BannedPlayer: MinecraftServerPlayerConfiguration {

        /// Player ID.
        let id: UUID?
        /// Player name.
        let name: String
        /// Reason for the ban.
        let reason: String?

        init(id: UUID? = nil, name: String, reason: String? = nil) {
            self.id = id
            self.name = name
            self.reason = reason ?? "Banned by an admin."
        }

        init(_ player: MinecraftPlayerInfo) {
            self.init(id: player.id, name: player.name)
        }

        init(_ player: MinecraftPlayerInfo, reason: String?) {
            self.init(id: player.id, name: player.name, reason: reason)
        }

        enum CodingKeys: String, CodingKey {
            case id = "uuid"
            case name
            case reason
        }

        static func ==(lhs: BannedPlayer, rhs: BannedPlayer) -> Bool {
            // equal if same id or name, reason doesn't matter
            if let lhsID = lhs.id, let rhsID = rhs.id {
                return lhsID == rhsID
            }
            else {
                return lhs.name == rhs.name
            }
        }
    }

    /// Minecraft server banned players list.
    typealias BannedPlayers = Set<BannedPlayer>
}

// MARK: - Helpers
extension MinecraftServer {
    /// Read the JSON config file at the given URL.
    static func readPlayerConfigurationJSON<T: MinecraftServerPlayerConfiguration>(at url: URL) throws -> [T] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            // file does not exist, return empty configuration
            return []
        }
        let data = try Data(contentsOf: url, options: .uncached)
        return try JSONDecoder().decode([T].self, from: data)
    }

    /// Update the JSON config file at the given URL with the provided data.
    static func updatePlayerConfigurationJSON<T: MinecraftServerPlayerConfiguration>(at url: URL, with config: [T]) throws {
        let data = try JSONEncoder().encode(Set(config))
        try data.write(to: url, options: .atomic)
    }

    /// Read the legacy TXT config file at the given URL.
    static func readLegacyPlayerConfigurationTXT(at url: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            // file does not exist, return empty configuration
            return []
        }
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Update the legacy TXT config file at the given URL with the provided data.
    static func updateLegacyPlayerConfigurationTXT<T: MinecraftServerPlayerConfiguration>(at url: URL, with config: [T]) throws {
        let content = Set(config).map(\.name).joined(separator: "\n")
        try content.write(toFile: url.path, atomically: true, encoding: .utf8)
    }
}
