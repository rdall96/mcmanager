//
//  ServerMetrics.swift
//
//
//  Created by Ricky Dall'Armellina on 8/5/23.
//

import Foundation

extension Server {
    public struct Metrics {
        /// If true, this server needs a restart in order to apply all updated configurations
        public let needsRestart: Bool
        /// CPU usage for the server process
        public let cpuPercent: Double
        /// Memory usage (bytes) for the server process
        public let memoryUsageBytes: UInt
        
        @_spi(MCManager_Runtime)
        public init(
            needsRestart: Bool,
            cpuPercent: Double,
            memoryUsage: UInt
        ) {
            self.needsRestart = needsRestart
            self.cpuPercent = cpuPercent
            self.memoryUsageBytes = memoryUsage
        }
    }
}

extension Server.Metrics: Codable {
    private enum CodingKeys: String, CodingKey {
        case needsRestart = "needs_restart"
        case cpuPercent = "cpu_percent"
        case memoryUsageBytes = "memory_usage"
    }
}
