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
    struct Properties: Content {
        var allowFlight: MCBool?
        var allowNether: MCBool?
        var difficulty: Difficulty?
        var enableCommandBlock: MCBool?
        var enableStatus: MCBool?
        var enforceSecureProfile: MCBool?
        var gamemode: MCString?
        var generateStructures: MCBool?
        var hardcore: MCBool?
        var hideOnlinePlayers: MCBool?
        var levelSeed: MCString?
        var leveType: MCString?
        var maxPlayers: MCInt?
        var maxTickTime: MCInt?
        var maxWorldSize: MCInt?
        var motd: MCString?
        var onlineMode: MCBool?
        var opPermissionLevel: MCInt?
        var playerIdleTimeout: MCInt?
        var pvp: MCBool?
        var resourcePack: MCString?
        var resourcePackPrompt: MCString?
        var requireResourcePack: MCBool?
        var simulationDistance: MCInt?
        var spawnAnimals: MCBool?
        var spawnMonsters: MCBool?
        var spawnNPCs: MCBool?
        var spawnProtection: MCInt?
        var viewDistance: MCInt?
        var whiteList: MCBool?
        
        var dictionary: [String:Property?] {
            var dictionary: [String : Property?] = [:]
            Mirror(reflecting: self).children.forEach { child in
                if let label = child.label {
                    dictionary[label] = child.value as? Property
                }
            }
            return dictionary
        }
        
        mutating func update(with newProperties: Properties) {
            allowFlight = newProperties.allowFlight ?? allowFlight
            allowNether = newProperties.allowNether ?? allowNether
            difficulty = newProperties.difficulty ?? difficulty
            enableCommandBlock = newProperties.enableCommandBlock ?? enableCommandBlock
            enableStatus = newProperties.enableStatus ?? enableStatus
            enforceSecureProfile = newProperties.enforceSecureProfile ?? enforceSecureProfile
            gamemode = newProperties.gamemode ?? gamemode
            generateStructures = newProperties.generateStructures ?? generateStructures
            hardcore = newProperties.hardcore ?? hardcore
            hideOnlinePlayers = newProperties.hideOnlinePlayers ?? hideOnlinePlayers
            levelSeed = newProperties.levelSeed ?? levelSeed
            leveType = newProperties.leveType ?? leveType
            maxPlayers = newProperties.maxPlayers ?? maxPlayers
            maxTickTime = newProperties.maxTickTime ?? maxTickTime
            maxWorldSize = newProperties.maxWorldSize ?? maxWorldSize
            motd = newProperties.motd ?? motd
            onlineMode = newProperties.onlineMode ?? onlineMode
            opPermissionLevel = newProperties.opPermissionLevel ?? opPermissionLevel
            playerIdleTimeout = newProperties.playerIdleTimeout ?? playerIdleTimeout
            pvp = newProperties.pvp ?? pvp
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
    }
}

extension MCServer.Properties {
    protocol Property: Codable {
        var description: String { get }
    }
    
    enum Difficulty: String, Property {
        case peaceful   // 0
        case easy       // 1
        case normal     // 2
        case hard       // 3
        
        var description: String { rawValue }
    }
    
    enum Gamemode: String, Property {
        case survival   // 0
        case creative   // 1
        case adventure  // 2
        case spectator  // 3
        
        var description: String { rawValue }
    }
    
    enum MCBool: String, Property {
        case `true`
        case `false`
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(Bool.self)
            self = value ? .true : .false
        }
        
        var description: String { rawValue }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            let value = self == .true
            try container.encode(value)
        }
    }
    
    struct MCString: RawRepresentable, Property {
        let rawValue: String
        
        var description: String { rawValue }
    }
    
    struct MCInt: RawRepresentable, Property {
        let rawValue: UInt
        
        init?(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(UInt.self)
        }
        
        var description: String { rawValue.description }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }
}
