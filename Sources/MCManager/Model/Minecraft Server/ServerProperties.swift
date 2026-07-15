//
//  ServerProperties.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor
import VaporToOpenAPI

extension MinecraftServer {
    @OpenAPIDescriptable
    /// Minecraft server properties.
    /// https://minecraft.fandom.com/wiki/Server.properties
    // All of these are optional to allow partial updates via the API
    // and to avoid breaking compatibility when a new property is added
    struct Properties: Content {
        /// Allow players to fly.
        var allowFlight: Bool?
        /// Allow players to enter the nether.
        var allowNether: Bool?
        /// Broadcast RCON commands to server operators.
        var broadcastRconToOps: Bool?
        /// Server difficulty.
        var difficulty: Difficulty?
        /// Enable the use of command blocks.
        var enableCommandBlock: Bool?
        /// Enable RCON.
        var enableRcon: Bool?
        /// Allow the server to respond to status requests, e.g. in the multiplayer server list.
        var enableStatus: Bool?
        /// Require players to have a Mojang-signed public key to join.
        var enforceSecureProfile: Bool?
        /// Default game mode for new players.
        var gamemode: Gamemode?
        /// Generate structures such as villages and strongholds.
        var generateStructures: Bool?
        /// Enable hardcore mode. Players are banned instead of dying.
        var hardcore: Bool?
        /// Hide player names and count from the server status response.
        var hideOnlinePlayers: Bool?
        /// Seed used to generate the world.
        var levelSeed: String?
        /// Type of world to generate.
        var levelType: String?
        /// Maximum number of players that can play on the server at once.
        var maxPlayers: UInt?
        /// Maximum number of milliseconds a single tick may take before the server is considered to have crashed.
        var maxTickTime: UInt?
        /// Maximum radius, in blocks, that the world border can expand to.
        var maxWorldSize: UInt?
        /// Message of the day, shown in the multiplayer server list.
        var motd: String?
        /// Verify player accounts with Mojang/Microsoft authentication servers.
        var onlineMode: Bool?
        /// Permission level granted to server operators.
        var opPermissionLevel: UInt?
        /// Number of minutes before an idle player is kicked. 0 disables this.
        var playerIdleTimeout: Int?
        /// Allow players to fight each other.
        var pvp: Bool?
        /// Password required to authenticate RCON connections.
        var rconPassword: String?
        /// Network port used for RCON connections.
        var rconPort: MinecraftServer.Port?
        /// URL of a resource pack players are prompted to download.
        var resourcePack: String?
        /// Custom message shown to players when prompted to download the resource pack.
        var resourcePackPrompt: String?
        /// Force players to accept the resource pack, or disconnect them.
        var requireResourcePack: Bool?
        /// Number of chunks in each direction the server actively simulates (mobs, redstone, etc), centered on each player.
        var simulationDistance: UInt?
        /// Allow animals to spawn.
        var spawnAnimals: Bool?
        /// Allow monsters to spawn.
        var spawnMonsters: Bool?
        /// Allow villagers to spawn.
        var spawnNPCs: Bool?
        /// Radius, in blocks, around the spawn point that non-operator players can't edit.
        var spawnProtection: UInt?
        /// Number of chunks in each direction the server sends to clients, centered on each player.
        var viewDistance: UInt?
        /// Restrict server access to players on the whitelist.
        var whiteList: Bool?

        init(
            allowFlight: Bool? = nil,
            allowNether: Bool? = nil,
            broadcastRconToOps: Bool? = nil,
            difficulty: Difficulty? = nil,
            enableCommandBlock: Bool? = nil,
            enableRcon: Bool? = nil,
            enableStatus: Bool? = nil,
            enforceSecureProfile: Bool? = nil,
            gamemode: Gamemode? = nil,
            generateStructures: Bool? = nil,
            hardcore: Bool? = nil,
            hideOnlinePlayers: Bool? = nil,
            levelSeed: String? = nil,
            levelType: String? = nil,
            maxPlayers: UInt? = nil,
            maxTickTime: UInt? = nil,
            maxWorldSize: UInt? = nil,
            motd: String? = nil,
            onlineMode: Bool? = nil,
            opPermissionLevel: UInt? = nil,
            playerIdleTimeout: Int? = nil,
            pvp: Bool? = nil,
            rconPassword: String? = nil,
            rconPort: MinecraftServer.Port? = nil,
            resourcePack: String? = nil,
            resourcePackPrompt: String? = nil,
            requireResourcePack: Bool? = nil,
            simulationDistance: UInt? = nil,
            spawnAnimals: Bool? = nil,
            spawnMonsters: Bool? = nil,
            spawnNPCs: Bool? = nil,
            spawnProtection: UInt? = nil,
            viewDistance: UInt? = nil,
            whiteList: Bool? = nil
        ) {
            self.allowFlight = allowFlight
            self.allowNether = allowNether
            self.broadcastRconToOps = broadcastRconToOps
            self.difficulty = difficulty
            self.enableCommandBlock = enableCommandBlock
            self.enableRcon = enableRcon
            self.enableStatus = enableStatus
            self.enforceSecureProfile = enforceSecureProfile
            self.gamemode = gamemode
            self.generateStructures = generateStructures
            self.hardcore = hardcore
            self.hideOnlinePlayers = hideOnlinePlayers
            self.levelSeed = levelSeed
            self.levelType = levelType
            self.maxPlayers = maxPlayers
            self.maxTickTime = maxTickTime
            self.maxWorldSize = maxWorldSize
            self.motd = motd
            self.onlineMode = onlineMode
            self.opPermissionLevel = opPermissionLevel
            self.playerIdleTimeout = playerIdleTimeout
            self.pvp = pvp
            self.rconPassword = rconPassword
            self.rconPort = rconPort
            self.resourcePack = resourcePack
            self.resourcePackPrompt = resourcePackPrompt
            self.requireResourcePack = requireResourcePack
            self.simulationDistance = simulationDistance
            self.spawnAnimals = spawnAnimals
            self.spawnMonsters = spawnMonsters
            self.spawnNPCs = spawnNPCs
            self.spawnProtection = spawnProtection
            self.viewDistance = viewDistance
            self.whiteList = whiteList
        }

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
        enum CodingKeys: String, CodingKey {
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

        // Custom Codable methods.
        // Nothing changes here from the default, but Fluent does things differently under the hood (Mirror reflection)
        // which tricks VaporToOpenAPI in reporting the wrong data schema.

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            allowFlight = try container.decodeIfPresent(Bool.self, forKey: .allowFlight)
            allowNether = try container.decodeIfPresent(Bool.self, forKey: .allowNether)
            broadcastRconToOps = try container.decodeIfPresent(Bool.self, forKey: .broadcastRconToOps)
            difficulty = try container.decodeIfPresent(MinecraftServer.Properties.Difficulty.self, forKey: .difficulty)
            enableCommandBlock = try container.decodeIfPresent(Bool.self, forKey: .enableCommandBlock)
            enableRcon = try container.decodeIfPresent(Bool.self, forKey: .enableRcon)
            enableStatus = try container.decodeIfPresent(Bool.self, forKey: .enableStatus)
            enforceSecureProfile = try container.decodeIfPresent(Bool.self, forKey: .enforceSecureProfile)
            gamemode = try container.decodeIfPresent(MinecraftServer.Properties.Gamemode.self, forKey: .gamemode)
            generateStructures = try container.decodeIfPresent(Bool.self, forKey: .generateStructures)
            hardcore = try container.decodeIfPresent(Bool.self, forKey: .hardcore)
            hideOnlinePlayers = try container.decodeIfPresent(Bool.self, forKey: .hideOnlinePlayers)
            levelSeed = try container.decodeIfPresent(String.self, forKey: .levelSeed)
            levelType = try container.decodeIfPresent(String.self, forKey: .levelType)
            maxPlayers = try container.decodeIfPresent(UInt.self, forKey: .maxPlayers)
            maxTickTime = try container.decodeIfPresent(UInt.self, forKey: .maxTickTime)
            maxWorldSize = try container.decodeIfPresent(UInt.self, forKey: .maxWorldSize)
            motd = try container.decodeIfPresent(String.self, forKey: .motd)
            onlineMode = try container.decodeIfPresent(Bool.self, forKey: .onlineMode)
            opPermissionLevel = try container.decodeIfPresent(UInt.self, forKey: .opPermissionLevel)
            playerIdleTimeout = try container.decodeIfPresent(Int.self, forKey: .playerIdleTimeout)
            pvp = try container.decodeIfPresent(Bool.self, forKey: .pvp)
            rconPassword = try container.decodeIfPresent(String.self, forKey: .rconPassword)
            rconPort = try container.decodeIfPresent(MinecraftServer.Port.self, forKey: .rconPort)
            resourcePack = try container.decodeIfPresent(String.self, forKey: .resourcePack)
            resourcePackPrompt = try container.decodeIfPresent(String.self, forKey: .resourcePackPrompt)
            requireResourcePack = try container.decodeIfPresent(Bool.self, forKey: .requireResourcePack)
            simulationDistance = try container.decodeIfPresent(UInt.self, forKey: .simulationDistance)
            spawnAnimals = try container.decodeIfPresent(Bool.self, forKey: .spawnAnimals)
            spawnMonsters = try container.decodeIfPresent(Bool.self, forKey: .spawnMonsters)
            spawnNPCs = try container.decodeIfPresent(Bool.self, forKey: .spawnNPCs)
            spawnProtection = try container.decodeIfPresent(UInt.self, forKey: .spawnProtection)
            viewDistance = try container.decodeIfPresent(UInt.self, forKey: .viewDistance)
            whiteList = try container.decodeIfPresent(Bool.self, forKey: .whiteList)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(allowFlight, forKey: .allowFlight)
            try container.encodeIfPresent(allowNether, forKey: .allowNether)
            try container.encodeIfPresent(broadcastRconToOps, forKey: .broadcastRconToOps)
            try container.encodeIfPresent(difficulty, forKey: .difficulty)
            try container.encodeIfPresent(enableCommandBlock, forKey: .enableCommandBlock)
            try container.encodeIfPresent(enableRcon, forKey: .enableRcon)
            try container.encodeIfPresent(enableStatus, forKey: .enableStatus)
            try container.encodeIfPresent(enforceSecureProfile, forKey: .enforceSecureProfile)
            try container.encodeIfPresent(gamemode, forKey: .gamemode)
            try container.encodeIfPresent(generateStructures, forKey: .generateStructures)
            try container.encodeIfPresent(hardcore, forKey: .hardcore)
            try container.encodeIfPresent(hideOnlinePlayers, forKey: .hideOnlinePlayers)
            try container.encodeIfPresent(levelSeed, forKey: .levelSeed)
            try container.encodeIfPresent(levelType, forKey: .levelType)
            try container.encodeIfPresent(maxPlayers, forKey: .maxPlayers)
            try container.encodeIfPresent(maxTickTime, forKey: .maxTickTime)
            try container.encodeIfPresent(maxWorldSize, forKey: .maxWorldSize)
            try container.encodeIfPresent(motd, forKey: .motd)
            try container.encodeIfPresent(onlineMode, forKey: .onlineMode)
            try container.encodeIfPresent(opPermissionLevel, forKey: .opPermissionLevel)
            try container.encodeIfPresent(playerIdleTimeout, forKey: .playerIdleTimeout)
            try container.encodeIfPresent(pvp, forKey: .pvp)
            try container.encodeIfPresent(rconPassword, forKey: .rconPassword)
            try container.encodeIfPresent(rconPort, forKey: .rconPort)
            try container.encodeIfPresent(resourcePack, forKey: .resourcePack)
            try container.encodeIfPresent(resourcePackPrompt, forKey: .resourcePackPrompt)
            try container.encodeIfPresent(requireResourcePack, forKey: .requireResourcePack)
            try container.encodeIfPresent(simulationDistance, forKey: .simulationDistance)
            try container.encodeIfPresent(spawnAnimals, forKey: .spawnAnimals)
            try container.encodeIfPresent(spawnMonsters, forKey: .spawnMonsters)
            try container.encodeIfPresent(spawnNPCs, forKey: .spawnNPCs)
            try container.encodeIfPresent(spawnProtection, forKey: .spawnProtection)
            try container.encodeIfPresent(viewDistance, forKey: .viewDistance)
            try container.encodeIfPresent(whiteList, forKey: .whiteList)
        }
    }
}

// MARK: - Custom property types

protocol MinecraftServerPropertyValue: Codable, RawRepresentable, CustomStringConvertible {}

extension MinecraftServer.Properties {

    /// Minecraft difficulty value.
    /// Starting with Minecraft 1.14, these values are expressed as strings: https://minecraft.wiki/w/Java_Edition_18w48a
    /// However, for legacy reasons, the game still supports and parses Int values correctly, so we use UInt for the rawValue.
    enum Difficulty: UInt, MinecraftServerPropertyValue {
        case peaceful = 0
        case easy = 1
        case normal = 2
        case hard = 3

        var description: String { String(rawValue) }
    }

    /// Minecraft gamemode value.
    /// Starting with Minecraft 1.14, these values are expressed as strings: https://minecraft.wiki/w/Java_Edition_18w48a
    /// However, for legacy reasons, the game still supports and parses Int values correctly, so we use UInt for the rawValue.
    enum Gamemode: UInt, MinecraftServerPropertyValue {
        case survival = 0
        case creative = 1
        case adventure = 2
        case spectator = 3

        var description: String { String(rawValue) }
    }
}

extension MinecraftServer.Port: MinecraftServerPropertyValue {}
