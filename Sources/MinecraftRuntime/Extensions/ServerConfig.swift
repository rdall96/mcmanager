//
//  ServerConfig.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import DockerSwiftAPI
@_spi(MinecraftRuntime) import MCManager_Shared

extension Server.Config {
    
    static var defaults: Set<Self> {
        [
            .init("ALLOW_FLIGHT", value: .flag(false)),
            .init("ALLOW_NETHER", value: .flag(true)),
            .init("DIFFICULTY", value: .text("easy")),
            .init("ENABLE_COMMAND_BLOCK", value: .flag(false)),
            .init("ENABLE_STATUS", value: .flag(true)),
            .init("ENFORCE_SECURE_PROFILE", value: .flag(true)),
            .init("GAMEMODE", value: .text("survival")),
            .init("GENERATE_STRUCTURES", value: .flag(true)),
            .init("HARDCORE", value: .flag(false)),
            .init("HIDE_ONLINE_PLAYERS", value: .flag(false)),
            .init("LEVEL_SEED", value: .text("")),
            .init("LEVEL_TYPE", value: .text("minecraft:normal")),
            .init("MAX_PLAYERS", value: .number(10)),
            .init("MOTD", value: .text("Hosted with MCManager")),
            .init("ONLINE_MODE", value: .flag(true)),
            .init("PLAYER_IDLE_TIMEOUT", value: .number(0)),
            .init("PVP", value: .flag(true)),
            .init("RESOURCE_PACK", value: .text("")),
            .init("RESOURCE_PACK_PROMPT", value: .text("")),
            .init("REQUIRE_RESOURCE_PACK", value: .flag(false)),
            .init("SIMULATION_DISTANCE", value: .number(10)),
            .init("SPAWN_ANIMALS", value: .flag(true)),
            .init("SPAWN_MONSTERS", value: .flag(true)),
            .init("SPAWN_NPCS", value: .flag(true)),
            .init("SPAWN_PROTECTION", value: .number(16)),
            .init("VIEW_DISTANCE", value: .number(10)),
            .init("WHITE_LIST", value: .flag(false)),
        ]
    }
    
    /// An environmetn varaible representation of the current property as key=value
    var environmentVariable: Docker.ContainerSpec.EnvironmentVariable {
        .init(key: id, value: value.description)
    }
    
    /// Read the server config at the given file path. If the config file can't be found, you can specify to create one using the default values
    static func read(at path: URL, createDefault: Bool = false) throws -> Set<Server.Config> {
        // if the file doesn't exist, create it usign the defaults
        if !FileManager.default.fileExists(atPath: path.path), createDefault {
            try PropertyListEncoder().encode(defaults)
                .write(to: path)
        }
        // read the file contents
        do {
            let data = try Data(contentsOf: path)
            return try PropertyListDecoder().decode(Set<Server.Config>.self, from: data)
        }
        catch {
            throw MCRError.corruptedServerConfiguration(path, error)
        }
    }
}
