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
        case allowedServerPorts = "allowed_server_ports"
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: FieldKeys.serverStatusTTLSeconds.rawValue)
    /// Time to live for the server status.
    /// A higher value means requests will respond faster since they will be reading from cache, but the information could possibly be outdated.
    /// Set this to 0 to disable caching all together.
    public var serverStatusTTLSeconds: UInt
    
    @Field(key: FieldKeys.allowedServerPorts.rawValue)
    /// Ports allowed for server creation.
    /// This can be a combination of comma-separated port values and a port range
    /// Example: 12345,25500-25599,32210
    /// Note: Ports outside of the follwoing range will be automatically discarded as they are either invalid or reserved: 1024-65535
    public var allowedServerPorts: String
    
    public init() {}
    
    public convenience init(
        serverStatusTTLSeconds: UInt,
        allowedServerPorts: String
    ) {
        self.init()
        self.serverStatusTTLSeconds = serverStatusTTLSeconds
        self.allowedServerPorts = allowedServerPorts.replacingOccurrences(of: " ", with: "")
    }
    
    @_spi(MCManager_Server) public var allowedServerPortsData: Set<UInt16> {
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
        case serverStatusTTLSeconds = "server_status_ttl_seconds"
        case allowedServerPorts = "allowed_server_ports"
    }
    
    // override decoding to ensure we do type checking
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            serverStatusTTLSeconds: try container.decode(UInt.self, forKey: .serverStatusTTLSeconds),
            allowedServerPorts: try container.decode(String.self, forKey: .allowedServerPorts)
        )
    }
    
    // override encoding to ignore the settings id
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverStatusTTLSeconds, forKey: .serverStatusTTLSeconds)
        try container.encode(allowedServerPorts, forKey: .allowedServerPorts)
    }
}

// MARK: - Defaults and parameters
extension Settings {
    public static var validPortRange: ClosedRange<UInt16> { 1024...65535 }
}
