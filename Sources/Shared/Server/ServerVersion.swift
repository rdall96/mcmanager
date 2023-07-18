//
//  ServerVersion.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    public struct Version {
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
        
        public var description: String {
            var text = "\(major).\(minor)"
            if let patch {
                text += ".\(String(patch))"
            }
            if let `extension` {
                text += "-\(`extension`)"
            }
            return text
        }
    }
}

extension Server.Version: Equatable, Comparable {
    public static func < (lhs: Server.Version, rhs: Server.Version) -> Bool {
        // in most cases the major version will be the same (who knows if Mojang will ever create Minecraft 2.0)
        guard lhs.major == rhs.major else {
            return lhs.major > rhs.major
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

extension Server.Version: Codable {
    
    @_spi(MCmanager_Tests)
    public init?(string: String) {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        if let version = Server.Version(string: text) {
            self = version
        }
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "\(text) is not a valid server version"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var contaier = encoder.singleValueContainer()
        try contaier.encode(description)
    }
}

extension Server.Version {
    @_spi(MCManager_Server)
    public static var none: Server.Version {
        Server.Version(major: 0, minor: 0)
    }
}
