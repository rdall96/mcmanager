//
//  ServerProperties+Defaults.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation

extension MCServer.Properties {

    /// Default server property values.
    static var defaults: Self {
        MCServer.Properties(
            allowFlight: false,
            allowNether: true,
            broadcastRconToOps: false,
            difficulty: .easy,
            enableCommandBlock: false,
            enableRcon: false,
            enableStatus: true,
            enforceSecureProfile: true,
            gamemode: .survival,
            generateStructures: true,
            hardcore: false,
            hideOnlinePlayers: false,
            levelSeed: nil,
            levelType: "minecraft:normal",
            maxPlayers: 10,
            maxTickTime: 60000,
            maxWorldSize: 29999984,
            motd: "Hosted with MCManager",
            onlineMode: true,
            opPermissionLevel: 4,
            playerIdleTimeout: 0,
            pvp: true,
            rconPassword: nil,
            rconPort: nil,
            resourcePack: nil,
            resourcePackPrompt: nil,
            requireResourcePack: false,
            simulationDistance: 10,
            spawnAnimals: true,
            spawnMonsters: true,
            spawnNPCs: true,
            spawnProtection: 16,
            viewDistance: 10,
            whiteList: false
        )
    }

    // MARK: read/write

    /// Read the server config at the given file path. If the config file can't be found, you can specify to create one using the default values
    static func read(at url: URL, createDefault: Bool = false) throws -> Self {
        // if the file doesn't exist, create it usign the defaults
        if !FileManager.default.fileExists(atPath: url.path), createDefault {
            try defaults.write(to: url)
        }
        // read the file contents
        do {
            let data = try Foundation.Data(contentsOf: url)
            return try PropertyListDecoder().decode(Self.self, from: data)
        }
        catch {
            throw MCServerError.systemError(error)
        }
    }
    
    func write(to url: URL) throws {
        try PropertyListEncoder().encode(self)
            .write(to: url, options: .atomic)
    }
}
