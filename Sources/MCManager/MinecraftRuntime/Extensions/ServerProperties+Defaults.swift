//
//  ServerProperties+Defaults.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import DockerSwiftAPI

extension MCServer.Properties {
    
    static var defaults: Self {
        .init([
            "ALLOW_FLIGHT" : .flag(false),
            "ALLOW_NETHER" : .flag(true),
            "DIFFICULTY" : .text("easy"),
            "ENABLE_COMMAND_BLOCK" : .flag(false),
            "ENABLE_STATUS" : .flag(true),
            "ENFORCE_SECURE_PROFILE" : .flag(true),
            "GAMEMODE" : .text("survival"),
            "GENERATE_STRUCTURES" : .flag(true),
            "HARDCORE" : .flag(false),
            "HIDE_ONLINE_PLAYERS" : .flag(false),
            "LEVEL_SEED" : .text(""),
            "LEVEL_TYPE" : .text("minecraft:normal"),
            "MAX_PLAYERS" : .number(10),
            "MOTD" : .text("Hosted with MCManager"),
            "ONLINE_MODE" : .flag(true),
            "OP_PERMISSION_LEVEL" : .number(4),
            "PLAYER_IDLE_TIMEOUT" : .number(0),
            "PVP" : .flag(true),
            "RESOURCE_PACK" : .text(""),
            "RESOURCE_PACK_PROMPT" : .text(""),
            "REQUIRE_RESOURCE_PACK" : .flag(false),
            "SIMULATION_DISTANCE" : .number(10),
            "SPAWN_ANIMALS" : .flag(true),
            "SPAWN_MONSTERS" : .flag(true),
            "SPAWN_NPCS" : .flag(true),
            "SPAWN_PROTECTION" : .number(16),
            "VIEW_DISTANCE" : .number(10),
            "WHITE_LIST" : .flag(false),
        ])
    }
    
    /// An environment varaible representation of the current property as key=value
    var environmentVariables: [Docker.ContainerSpec.EnvironmentVariable] {
        data.compactMap { .init(key: $0.key, value: $0.value.description) }
    }
    
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
            throw MCServerError.corruptedServerProperties(url, error)
        }
    }
    
    func write(to url: URL) throws {
        try PropertyListEncoder().encode(self)
            .write(to: url, options: .atomic)
    }
}
