//
//  ServerInfo.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    public struct Info {
        public let status: Status
        /// Number of active players on the server
        public let onlinePlayerCount: UInt?
        /// CPU usage for the server process
        public let cpuUsage: UInt64
        /// Memory usage (bytes) for the server process
        public let memoryUsageBytes: UInt64
    }
}

extension Server.Info: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case status
        case onlinePlayerCount = "online_players"
        case cpuUsage = "cpu_usage"
        case memoryUsageBytes = "memory_usage"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try container.decodeIfPresent(Server.Status.self, forKey: .status) ?? .unknown
        onlinePlayerCount = try? container.decode(UInt.self, forKey: .onlinePlayerCount)
        cpuUsage = try container.decode(UInt64.self, forKey: .cpuUsage)
        memoryUsageBytes = try container.decode(UInt64.self, forKey: .memoryUsageBytes)
    }
}

extension Server.Info {
    @_spi(MCManager_Runtime)
    public init(
        status: Server.Status,
        onlinePlayerCount: UInt = 0,
        cpuUsage: UInt64 = 0,
        memoryUsage: UInt64 = 0
    ) {
        self.status = status
        self.onlinePlayerCount = onlinePlayerCount
        self.cpuUsage = cpuUsage
        self.memoryUsageBytes = memoryUsage
    }
}
