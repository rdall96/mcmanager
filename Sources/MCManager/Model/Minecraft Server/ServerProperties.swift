//
//  ServerProperties.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor

extension MCServer {
    /// https://minecraft.fandom.com/wiki/Server.properties
    // All of these are optional to allow partial updates via the API
    // and to avoid breaking compatibility when a new property is added
    struct Properties: Content {
        var allowFlight: Bool?
        var allowNether: Bool?
        var broadcastRconToOps: Bool?
        var difficulty: Difficulty?
        var enableCommandBlock: Bool?
        var enableRcon: Bool?
        var enableStatus: Bool?
        var enforceSecureProfile: Bool?
        var gamemode: Gamemode?
        var generateStructures: Bool?
        var hardcore: Bool?
        var hideOnlinePlayers: Bool?
        var levelSeed: String?
        var levelType: String?
        var maxPlayers: UInt?
        var maxTickTime: UInt?
        var maxWorldSize: UInt?
        var motd: String?
        var onlineMode: Bool?
        var opPermissionLevel: UInt?
        var playerIdleTimeout: Int?
        var pvp: Bool?
        var rconPassword: String?
        var rconPort: Port?
        var resourcePack: String?
        var resourcePackPrompt: String?
        var requireResourcePack: Bool?
        var simulationDistance: UInt?
        var spawnAnimals: Bool?
        var spawnMonsters: Bool?
        var spawnNPCs: Bool?
        var spawnProtection: UInt?
        var viewDistance: UInt?
        var whiteList: Bool?
        
        mutating func update(with newProperties: Properties) {
            allowFlight = newProperties.allowFlight ?? allowFlight
            allowNether = newProperties.allowNether ?? allowNether
            difficulty = newProperties.difficulty ?? difficulty
            broadcastRconToOps = newProperties.broadcastRconToOps ?? broadcastRconToOps
            enableCommandBlock = newProperties.enableCommandBlock ?? enableCommandBlock
            enableRcon = newProperties.enableRcon ?? enableRcon
            enableStatus = newProperties.enableStatus ?? enableStatus
            enforceSecureProfile = newProperties.enforceSecureProfile ?? enforceSecureProfile
            gamemode = newProperties.gamemode ?? gamemode
            generateStructures = newProperties.generateStructures ?? generateStructures
            hardcore = newProperties.hardcore ?? hardcore
            hideOnlinePlayers = newProperties.hideOnlinePlayers ?? hideOnlinePlayers
            levelSeed = newProperties.levelSeed ?? levelSeed
            levelType = newProperties.levelType ?? levelType
            maxPlayers = newProperties.maxPlayers ?? maxPlayers
            maxTickTime = newProperties.maxTickTime ?? maxTickTime
            maxWorldSize = newProperties.maxWorldSize ?? maxWorldSize
            motd = newProperties.motd ?? motd
            onlineMode = newProperties.onlineMode ?? onlineMode
            opPermissionLevel = newProperties.opPermissionLevel ?? opPermissionLevel
            playerIdleTimeout = newProperties.playerIdleTimeout ?? playerIdleTimeout
            pvp = newProperties.pvp ?? pvp
            rconPassword = newProperties.rconPassword ?? rconPassword
            rconPort = newProperties.rconPort ?? rconPort
            resourcePack = newProperties.resourcePack ?? resourcePack
            resourcePackPrompt = newProperties.resourcePackPrompt ?? resourcePackPrompt
            requireResourcePack = newProperties.requireResourcePack ?? requireResourcePack
            simulationDistance = newProperties.simulationDistance ?? simulationDistance
            spawnAnimals = newProperties.spawnAnimals ?? spawnAnimals
            spawnMonsters = newProperties.spawnMonsters ?? spawnMonsters
            spawnNPCs = newProperties.spawnNPCs ?? spawnNPCs
            spawnProtection = newProperties.spawnProtection ?? spawnProtection
            viewDistance = newProperties.viewDistance ?? viewDistance
            whiteList = newProperties.whiteList ?? whiteList
        }

        // These map to the actual Minecraft property values: https://minecraft.wiki/w/Server.properties
        // Intentional so a human looking at the stored server properties file on disk can easily recognize the familiar options
        private enum CodingKeys: String, CodingKey {
            case allowFlight = "allow-flight"
            case allowNether = "allow-nether"
            case broadcastRconToOps = "broadcast-rcon-to-ops"
            case difficulty
            case enableCommandBlock = "enable-command-block"
            case enableRcon = "enable-rcon"
            case enableStatus = "enable-status"
            case enforceSecureProfile = "enforce-secure-profile"
            case gamemode
            case generateStructures = "generate-structures"
            case hardcore
            case hideOnlinePlayers = "hide-online-players"
            case levelSeed = "level-seed"
            case levelType = "level-type"
            case maxPlayers = "max-players"
            case maxTickTime = "max-tick-time"
            case maxWorldSize = "max-world-size"
            case motd
            case onlineMode = "online-mode"
            case opPermissionLevel = "op-permission-level"
            case playerIdleTimeout = "player-idle-timeout"
            case pvp
            case rconPassword = "rcon.password"
            case rconPort = "rcon.port"
            case resourcePack = "resource-pack"
            case resourcePackPrompt = "resource-pack-prompt"
            case requireResourcePack = "require-resource-pack"
            case simulationDistance = "simulation-distance"
            case spawnAnimals = "spawn-animals"
            case spawnMonsters = "spawn-monsters"
            case spawnNPCs = "spawn-npcs"
            case spawnProtection = "spawn-protection"
            case viewDistance = "view-distance"
            case whiteList = "white-list"
        }
    }
}

protocol MCServerPropertyValue: Codable, RawRepresentable, CustomStringConvertible {}

extension MCServer.Properties {

    /// Minecraft difficulty value.
    /// Starting with Minecraft 1.14, these values are expressed as strings: https://minecraft.wiki/w/Java_Edition_18w48a
    /// However, for legacy reasons, the game still supports and parses Int values correctly, so we use UInt for the rawValue.
    enum Difficulty: UInt, MCServerPropertyValue {
        case peaceful = 0
        case easy = 1
        case normal = 2
        case hard = 3

        var description: String { String(rawValue) }
    }

    /// Minecraft gamemode value.
    /// Starting with Minecraft 1.14, these values are expressed as strings: https://minecraft.wiki/w/Java_Edition_18w48a
    /// However, for legacy reasons, the game still supports and parses Int values correctly, so we use UInt for the rawValue.
    enum Gamemode: UInt, MCServerPropertyValue {
        case survival = 0
        case creative = 1
        case adventure = 2
        case spectator = 3

        var description: String { String(rawValue) }
    }

    /// Minecraft server port value.
    /// Automatically validates any interger value from the valid range of TCP/UDP ports.
    struct Port: MCServerPropertyValue {
        private static let allowedPortRange: ClosedRange<UInt> = 1...65535

        let rawValue: UInt

        init?(rawValue: UInt) {
            guard Self.allowedPortRange.contains(rawValue) else {
                return nil
            }
            self.rawValue = rawValue
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(UInt.self)
            guard let value = Self.init(rawValue: rawValue) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid value for \(Self.self): \(rawValue)"
                ))
            }
            self = value
        }

        var description: String { rawValue.description }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }
}
