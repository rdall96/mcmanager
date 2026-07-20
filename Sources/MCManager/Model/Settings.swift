//
//  Settings.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent
import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Global application settings.
final class Settings: Model, Content, @unchecked Sendable {
    static let schema = "settings"

    enum FieldKeys: FieldKey {
        case serverStatusCacheTTLSeconds = "server_status_cache_ttl_seconds"
        case serverSupportCacheTTLSeconds = "server_support_cache_ttl_seconds"
        case allowedServerPorts = "allowed_server_ports"
        case maxRunningServers = "max_running_servers"
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.serverStatusCacheTTLSeconds.rawValue)
    /// Time to live for the server status.
    /// A higher value means requests will respond faster since they will be reading from cache, but the information could possibly be outdated.
    /// Important actions on servers, such as start/stop/restart, will automatically invalidate the cache.
    /// Set this to 0 to disable caching all together.
    var serverStatusCacheTTLSeconds: UInt

    @Field(key: FieldKeys.serverSupportCacheTTLSeconds.rawValue)
    /// Time to live for the server runtime support cache.
    /// The server runtime support determines what types and versions of Minecraft servers can be created.
    /// The runtime support request is very expensive as we need to query what server versions are available online,
    /// however this data doesn't change very often, so we cache it by default in order to return faster responses to the user.
    /// Set this to 0 to disable caching this value.
    var serverSupportCacheTTLSeconds: UInt

    @Field(key: FieldKeys.allowedServerPorts.rawValue)
    /// Ports allowed for server creation.
    /// This can be a combination of comma-separated port values and a port range
    /// Example: 12345,25500-25599,32210
    /// Note: Ports outside of the follwoing range will be automatically discarded as they are either invalid or reserved: 1024-65535
    var allowedServerPorts: String
    
    @Field(key: FieldKeys.maxRunningServers.rawValue)
    /// The maximum number of concurrently running servers.
    var maxRunningServers: UInt
    
    init() {}
    
    convenience init(
        serverStatusCacheTTLSeconds: UInt,
        serverSupportCacheTTLSeconds: UInt,
        allowedServerPorts: String,
        maxRunningServers: UInt
    ) {
        self.init()
        self.serverStatusCacheTTLSeconds = serverStatusCacheTTLSeconds
        self.serverSupportCacheTTLSeconds = serverSupportCacheTTLSeconds
        self.allowedServerPorts = allowedServerPorts.replacingOccurrences(of: " ", with: "")
        self.maxRunningServers = maxRunningServers
    }
    
    var allowedServerPortsData: Set<MinecraftServer.Port> {
        var ports = Set<MinecraftServer.Port>()
        for portValue in allowedServerPorts.split(separator: ",") {
            // if the portValue contains a `-` then it's a range, otherwise it's a single value
            if portValue.contains("-") {
                let portRangeValues = portValue.split(separator: "-", maxSplits: 1)
                guard let lowerBound = MinecraftServer.Port(String(portRangeValues[0])),
                      let upperBound = MinecraftServer.Port(String(portRangeValues[1])),
                      lowerBound <= upperBound
                else { continue }
                let portRange: ClosedRange<MinecraftServer.Port> = lowerBound...upperBound
                ports.formUnion(portRange)
            }
            else {
                guard let port = MinecraftServer.Port(String(portValue)) else { continue }
                ports.insert(port)
            }
        }
        return ports.intersection(MinecraftServer.Port.validPortRange)
    }
    
    // MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case serverStatusCacheTTLSeconds
        case serverSupportCacheTTLSeconds
        case allowedServerPorts
        case maxRunningServers
    }
    
    // override decoding to ensure we do type checking
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            serverStatusCacheTTLSeconds: try container.decode(UInt.self, forKey: .serverStatusCacheTTLSeconds),
            serverSupportCacheTTLSeconds: try container.decode(UInt.self, forKey: .serverSupportCacheTTLSeconds),
            allowedServerPorts: try container.decode(String.self, forKey: .allowedServerPorts),
            maxRunningServers: try container.decode(UInt.self, forKey: .maxRunningServers)
        )
    }
    
    // override encoding to ignore the settings id
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverStatusCacheTTLSeconds, forKey: .serverStatusCacheTTLSeconds)
        try container.encode(serverSupportCacheTTLSeconds, forKey: .serverSupportCacheTTLSeconds)
        try container.encode(allowedServerPorts, forKey: .allowedServerPorts)
        try container.encode(maxRunningServers, forKey: .maxRunningServers)
    }
}
