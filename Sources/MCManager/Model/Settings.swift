//
//  Settings.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent
import Vapor

final class Settings: Model, Content {
    static let schema = "settings"
    
    enum FieldKeys: FieldKey {
        case serverStatusCacheTTLSeconds = "server_status_cache_ttl_seconds"
        case allowedServerPorts = "allowed_server_ports"
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.serverStatusCacheTTLSeconds.rawValue)
    /// Time to live for the server status.
    /// A higher value means requests will respond faster since they will be reading from cache, but the information could possibly be outdated.
    /// Important actions on servers, such as start/stop/restart, will automatically invalidate the cache.
    /// Set this to 0 to disable caching all together.
    var serverStatusCacheTTLSeconds: UInt
    
    @Field(key: FieldKeys.allowedServerPorts.rawValue)
    /// Ports allowed for server creation.
    /// This can be a combination of comma-separated port values and a port range
    /// Example: 12345,25500-25599,32210
    /// Note: Ports outside of the follwoing range will be automatically discarded as they are either invalid or reserved: 1024-65535
    var allowedServerPorts: String
    
    init() {}
    
    convenience init(
        serverStatusCacheTTLSeconds: UInt,
        allowedServerPorts: String
    ) {
        self.init()
        self.serverStatusCacheTTLSeconds = serverStatusCacheTTLSeconds
        self.allowedServerPorts = allowedServerPorts.replacingOccurrences(of: " ", with: "")
    }
    
    var allowedServerPortsData: Set<UInt16> {
        var ports = Set<UInt16>()
        for portValue in allowedServerPorts.split(separator: ",") {
            // if the portValue contains a `-` then it's a range, otherwise it's a single value
            if portValue.contains("-") {
                let portRangeValues = portValue.split(separator: "-", maxSplits: 1)
                guard let lowerBound = UInt16(portRangeValues[0]),
                      let upperBound = UInt16(portRangeValues[1])
                else { continue }
                ports.formUnion(lowerBound...upperBound)
            }
            else {
                guard let port = UInt16(portValue) else { continue }
                ports.insert(port)
            }
        }
        return ports.intersection(Self.validPortRange)
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case serverStatusCacheTTLSeconds = "server_status_cache_ttl_seconds"
        case allowedServerPorts = "allowed_server_ports"
    }
    
    // override decoding to ensure we do type checking
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            serverStatusCacheTTLSeconds: try container.decode(UInt.self, forKey: .serverStatusCacheTTLSeconds),
            allowedServerPorts: try container.decode(String.self, forKey: .allowedServerPorts)
        )
    }
    
    // override encoding to ignore the settings id
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverStatusCacheTTLSeconds, forKey: .serverStatusCacheTTLSeconds)
        try container.encode(allowedServerPorts, forKey: .allowedServerPorts)
    }
}

// MARK: - Defaults and parameters
extension Settings {
    private static var validPortRange: ClosedRange<UInt16> { 1024...65535 }
    
    static var defaults: Settings {
        .init(
            serverStatusCacheTTLSeconds: 5,
            allowedServerPorts: "\(Settings.validPortRange.lowerBound)-\(Settings.validPortRange.upperBound)"
        )
    }
    
    /// If the server status cache is enabled
    var serverStatusCacheIsEnabled: Bool { serverStatusCacheTTLSeconds > 0 }
}
