//
//  Version.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

enum APIVersion: String {
    case v1
    case v2
}

struct AppVersion {
    let major: UInt
    let minor: UInt
    let patch: UInt
    
    private init(major: UInt, minor: UInt, patch: UInt) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Create a version object from the textual description
    init?(from description: String) {
        let components: [UInt] = description.split(separator: ".")
            .compactMap { UInt(String($0)) }
        guard components.count == 3 else { return nil }
        major = components[0]
        minor = components[1]
        patch = components[2]
    }
    
    /// A textual represenation of the service version
    var description: String {
        return "\(major).\(minor).\(patch)"
    }
}

// MARK: - Version numbers
extension AppVersion {
    static let v1_0_0: AppVersion = .init(major: 1, minor: 0, patch: 0)
    
    static let latest: AppVersion = .v1_0_0
}

// MARK: - Equatable
extension AppVersion: Equatable {}

// MARK: - Codable
extension AppVersion: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let version = AppVersion(from: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid version")
        }
        self = version
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
