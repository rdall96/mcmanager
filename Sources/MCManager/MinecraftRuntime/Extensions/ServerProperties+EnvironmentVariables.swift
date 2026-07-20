//
//  ServerProperties+EnvironmentVariables.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/11/26.
//

import Foundation
import DockerSwiftAPI

// A minimal typed representation of a decoded JSON value, used to disambiguate server properties after JSON encoding
// because JSONSerialization's `Any` can't tell them apart reliably.
private enum PropertyValue: Decodable {
    case bool(Bool)
    case int(Int)
    case string(String)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        // check bool before int to avoid mis-representing 'true' and 'false' as integer values where they are not supported
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        }
        else if let value = try? container.decode(Int.self) {
            self = .int(value)
        }
        else {
            self = .string(try container.decode(String.self))
        }
    }

    var stringValue: String {
        switch self {
        case .bool(let value): value ? "true" : "false"
        case .int(let value): String(value)
        case .string(let value): value
        }
    }
}

extension MinecraftServer.Properties {
    /// An environment variable representation of the server properties as key=value pairs.
    func generateEnvironmentVariables() throws -> [Docker.ContainerSpec.EnvironmentVariable] {
        // Encode the data into JSON, then decode it into a dictionary.
        // This achieves two things:
        // 1. Automatically converts keys to the Minecraft format (via CodingKeys)
        // 2. Cast the values to primitives that can easily be expressed an EnvironmentVariable value
        let data = try JSONEncoder().encode(self)
        let properties = try JSONDecoder().decode([String : PropertyValue].self, from: data)
        return properties.map {
            // The environment variable values expect SCREAMING_SNAKE_CASE, but the Minecraft default is kebak-case.
            let name = $0.key
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: ".", with: "_")
                .uppercased()
            return Docker.ContainerSpec.EnvironmentVariable(key: name, value: $0.value.stringValue)
        }
    }
}
