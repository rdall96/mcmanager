//
//  ServerMetrics.swift
//
//
//  Created by Ricky Dall'Armellina on 8/5/23.
//

import Foundation
import Vapor

extension MCServer {
    struct Metrics: Content {
        /// If true, this server needs a restart in order to apply all updated configurations
        let needsRestart: Bool
        /// CPU usage for the server process
        let cpuPercent: Double
        /// Memory usage (bytes) for the server process
        let memoryUsageBytes: UInt
        
        init(
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

// MARK: - Codable

extension MCServer.Metrics: Codable {
    private enum CodingKeys: String, CodingKey {
        case needsRestart = "needs_restart"
        case cpuPercent = "cpu_percent"
        case memoryUsageBytes = "memory_usage"
    }
}
