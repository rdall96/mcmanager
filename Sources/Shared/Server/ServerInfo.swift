//
//  ServerInfo.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    public struct Info {
        /// Current status of the server
        public let status: Status
        /// If true, this server needs a restart in order to apply all updated configurations
        public let needsRestart: Bool
        /// Number of active players on the server
        public let onlinePlayerCount: UInt?
        /// CPU usage for the server process
        public let cpuPercent: Double
        /// Memory usage (bytes) for the server process
        public let memoryUsageBytes: UInt
    }
}

extension Server.Info: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
        case needsRestart = "needs_restart"
        case onlinePlayerCount = "online_players"
        case cpuPercent = "cpu_percent"
        case memoryUsageBytes = "memory_usage"
    }
}

extension Server.Info {
    @_spi(MCManager_Runtime)
    public init(
        status: Server.Status,
        needsRestart: Bool = false,
        onlinePlayerCount: UInt = 0,
        cpuPercent: Double = 0,
        memoryUsage: UInt = 0
    ) {
        self.status = status
        self.needsRestart = needsRestart
        self.onlinePlayerCount = onlinePlayerCount
        self.cpuPercent = cpuPercent
        self.memoryUsageBytes = memoryUsage
    }
}
