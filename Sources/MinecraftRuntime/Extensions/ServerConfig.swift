//
//  ServerConfig.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import MCManager_Shared

extension Server.Config {
    
    private static var defaultJson: String {
        """
        [
        {
        "id": "ALLOW_FLIGHT",
        "value": false
        },
        {
        "id": "ALLOW_NETHER",
        "value": true
        },
        {
        "id": "DIFFICULTY",
        "value": "easy"
        },
        {
        "id": "ENABLE_COMMAND_BLOCK",
        "value": false
        },
        {
        "id": "ENABLE_STATUS",
        "value": true
        },
        {
        "id": "ENFORCE_SECURE_PROFILE",
        "value": true
        },
        {
        "id": "GAMEMODE",
        "value": "survival"
        },
        {
        "id": "GENERATE_STRUCTURES",
        "value": true
        },
        {
        "id": "HARDCORE",
        "value": false
        },
        {
        "id": "HIDE_ONLINE_PLAYERS",
        "value": false
        },
        {
        "id": "LEVEL_SEED",
        "value": ""
        },
        {
        "id": "LEVEL_TYPE",
        "value": "minecraft:normal"
        },
        {
        "id": "MAX_PLAYERS",
        "value": 10
        },
        {
        "id": "MOTD",
        "value": "Hosted with MCManager"
        },
        {
        "id": "ONLINE_MODE",
        "value": true
        },
        {
        "id": "PLAYER_IDLE_TIMEOUT",
        "value": 0
        },
        {
        "id": "PVP",
        "value": true
        },
        {
        "id": "RESOURCE_PACK",
        "value": ""
        },
        {
        "id": "RESOURCE_PACK_PROMPT",
        "value": ""
        },
        {
        "id": "REQUIRE_RESOURCE_PACK",
        "value": false
        },
        {
        "id": "SIMULATION_DISTANCE",
        "value": 10
        },
        {
        "id": "SPAWN_ANIMALS",
        "value": true
        },
        {
        "id": "SPAWN_MONSTERS",
        "value": true
        },
        {
        "id": "SPAWN_NPCS",
        "value": true
        },
        {
        "id": "SPAWN_PROTECTION",
        "value": 16
        },
        {
        "id": "VIEW_DISTANCE",
        "value": 10
        },
        {
        "id": "WHITE_LIST",
        "value": false
        }
        ]
        """
    }
    
    static var defaultData: Data { defaultJson.data(using: .utf8)! }
    
    /// An environmetn varaible representation of the current property as key=value
    var environmentVariable: String {
        "\(id)=\(value.description)"
    }
    
    /// Read the server config at the given file path. If the config file can't be found, you can specify to create one using the default values
    static func read(at path: URL, createDefault: Bool = false) throws -> Set<Server.Config> {
        // if the file doesn't exist, create it usign the defaults
        if !FileManager.default.fileExists(atPath: path.path), createDefault {
            try Server.Config.defaultData.write(to: path)
        }
        // read the file contents
        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode(Set<Server.Config>.self, from: data)
        }
        catch {
            throw MCRError.corruptedServerConfiguration(path, error)
        }
    }
}
