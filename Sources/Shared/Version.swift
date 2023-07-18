//
//  Version.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

public struct Version {
    public let major: UInt
    public let minor: UInt
    public let patch: UInt
    
    private init(major: UInt, minor: UInt, patch: UInt) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Create a version object from the textual description
    public init?(from description: String) {
        let components: [UInt] = description.split(separator: ".")
            .compactMap { UInt(String($0)) }
        guard components.count == 3 else { return nil }
        major = components[0]
        minor = components[1]
        patch = components[2]
    }
    
    /// A textual represenation of the service version
    public var description: String {
        return "\(major).\(minor).\(patch)"
    }
}

// MARK: - Version numbers
extension Version {
    public static let v1_0_0: Version = .init(major: 1, minor: 0, patch: 0)
    public static let current: Version = .v1_0_0
}

// MARK: - Equatable
extension Version: Equatable {}

// MARK: - Codable
extension Version: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let version = Version(from: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid version")
        }
        self = version
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
