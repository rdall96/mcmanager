//
//  ServerVersion.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor
import VaporToOpenAPI

extension MinecraftServer {
    /// Minecraft game version.
    struct Version: Content {
        let major: UInt
        let minor: UInt
        let patch: UInt?
        let `extension`: String?
        
        init(
            major: UInt,
            minor: UInt,
            patch: UInt? = nil,
            extension: String? = nil
        ) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.`extension` = `extension`
        }
        
        var description: String {
            var text = "\(major).\(minor)"
            if let patch {
                text += ".\(String(patch))"
            }
            if let `extension` {
                text += "-\(`extension`)"
            }
            return text
        }
        
        static var none: MinecraftServer.Version {
            MinecraftServer.Version(major: 0, minor: 0)
        }
    }
}

// MARK: - Comparable
extension MinecraftServer.Version: Equatable, Comparable {
    static func < (lhs: MinecraftServer.Version, rhs: MinecraftServer.Version) -> Bool {
        // Minecraft 1.21.x was the last game version to follow the long standing 1.x.x format.
        // In 2026 the game switched to using the year as the major version (i.e.: 26.1, 26.2, etc...)
        guard lhs.major == rhs.major else {
            return lhs.major < rhs.major
        }
        // compare minor versions
        guard lhs.minor == rhs.minor else {
            return lhs.minor < rhs.minor
        }
        // comapare patches
        let lhsPatch = lhs.patch ?? 0
        let rhsPatch = rhs.patch ?? 0
        guard lhsPatch == rhsPatch else {
            return lhsPatch < rhsPatch
        }
        // compare extensions - this is tricky becuase the extension is a string, so we just look at the alphabetical order
        let ordered: [String] = [
            lhs.extension ?? "",
            rhs.extension ?? ""
        ].sorted()
        return ordered.first == lhs.extension
    }
}

// MARK: - Codable
extension MinecraftServer.Version: Codable {
    
    init?(string: String) {
        // the version could be:
        // 1.12
        // 1.19.2
        // 1.9.4-forge_12.17.0.2317-1.9.4
        // 1.9-forge_12.16.1.1938-1.9.0
        
        // Get the major version
        let majorComponents = string.split(separator: ".", maxSplits: 1)
        guard majorComponents.count == 2,
              let majorVersion = UInt(majorComponents[0])
        else { return nil }
        major = majorVersion
        
        // if we have a "-" then we need to split further to get the minor version, and the descriptor
        if majorComponents[1].contains("-") {
            let components = majorComponents[1].split(separator: "-", maxSplits: 1)
            guard components.count == 2 else { return nil }
            // check for patch versions
            if components[0].contains(".") {
                let minorComponents = components[0].split(separator: ".", maxSplits: 1)
                guard minorComponents.count == 2,
                      let minorVersion = UInt(minorComponents[0]),
                      let patchVersion = UInt(minorComponents[1])
                else { return nil }
                minor = minorVersion
                patch = patchVersion
            }
            else {
                guard let minorVersion = UInt(components[0]) else { return nil }
                minor = minorVersion
                patch = nil
            }
            `extension` = String(components[1])
        }
        // If we only have a ".", then we split for minor and patch versions
        else if majorComponents[1].contains(".") {
            let minorComponents = majorComponents[1].split(separator: ".", maxSplits: 1)
            guard minorComponents.count == 2,
                  let minorVersion = UInt(minorComponents[0]),
                  let patchVersion = UInt(minorComponents[1])
            else { return nil }
            minor = minorVersion
            patch = patchVersion
            `extension` = nil
        }
        // Otherwise, we have no patch version
        else {
            guard let minorVersion = UInt(majorComponents[1]) else { return nil }
            minor = minorVersion
            patch = nil
            `extension` = nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        if let version = MinecraftServer.Version(string: text) {
            self = version
        }
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\(text) is not a valid server version"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var contaier = encoder.singleValueContainer()
        try contaier.encode(description)
    }
}

// MARK: - Open API Spec
extension MinecraftServer.Version: OpenAPIDescriptable {
    static var openAPIDescription: OpenAPIDescriptionType? {
        "Minecraft game version."
    }
}
