//
//  Settings.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent

final public class Settings: Model {
    @_spi(MCManager_Server)
    public static let schema = "settings"
    
    @_spi(MCManager_Server)
    public enum FieldKeys: FieldKey {
        case serverStatusTTLSeconds = "server_status_ttl_seconds"
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: FieldKeys.serverStatusTTLSeconds.rawValue)
    public var serverStatusTTLSeconds: UInt
    
    public init() {}
    
    public convenience init(
        serverStatusTTLSeconds: UInt
    ) {
        self.init()
        self.serverStatusTTLSeconds = serverStatusTTLSeconds
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case serverStatusTTLSeconds = "server_status_ttl_seconds"
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            serverStatusTTLSeconds: try container.decode(UInt.self, forKey: .serverStatusTTLSeconds)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverStatusTTLSeconds, forKey: .serverStatusTTLSeconds)
    }
}
