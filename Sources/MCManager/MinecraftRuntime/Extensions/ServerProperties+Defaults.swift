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
        MCServer.Properties(
            allowFlight: .false,
            allowNether: .true,
            difficulty: .easy,
            enableCommandBlock: .false,
            enableStatus: .true,
            enforceSecureProfile: .true,
            gamemode: .init(rawValue: "survival"),
            generateStructures: .true,
            hardcore: .false,
            hideOnlinePlayers: .false,
            levelSeed: .init(rawValue: ""),
            leveType: .init(rawValue: "minecraft:normal"),
            maxPlayers: .init(rawValue: 10),
            maxTickTime: .init(rawValue: 60000),
            maxWorldSize: .init(rawValue: 29999984),
            motd: .init(rawValue: "Hosted with MCManager"),
            onlineMode: .true,
            opPermissionLevel: .init(rawValue: 4),
            playerIdleTimeout: .init(rawValue: 0),
            pvp: .true,
            resourcePack: .init(rawValue: ""),
            resourcePackPrompt: .init(rawValue: ""),
            requireResourcePack: .false,
            simulationDistance: .init(rawValue: 10),
            spawnAnimals: .true,
            spawnMonsters: .true,
            spawnNPCs: .true,
            spawnProtection: .init(rawValue: 16),
            viewDistance: .init(rawValue: 10),
            whiteList: .false
        )
    }
    
    /// Number of properties that aren't nil
    var count: UInt {
        dictionary.reduce(0) { result, next in
            guard next.value != nil else {
                return result
            }
            return result + 1
        }
    }
    
    /// An environment varaible representation of the current property as key=value
    var environmentVariables: [Docker.ContainerSpec.EnvironmentVariable] {
        dictionary.compactMap {
            // Skip nil values
            guard let value = $0.value else { return nil }
            // Env var names should be snake case and all caps
            let name = camelCaseToSnakeCase($0.key).uppercased()
            return Docker.ContainerSpec.EnvironmentVariable(
                key: name,
                value: value.description
            )
        }
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
            throw MCServerError.systemError(error)
        }
    }
    
    func write(to url: URL) throws {
        try PropertyListEncoder().encode(self)
            .write(to: url, options: .atomic)
    }
}

fileprivate func camelCaseToSnakeCase(_ input: String) -> String {
    let pattern = "([a-z0-9])([A-Z])"
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: input.utf16.count)
    let result = regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "$1_$2")
    return result.lowercased()
}
