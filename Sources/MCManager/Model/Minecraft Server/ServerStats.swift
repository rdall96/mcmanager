//
//  ServerStats.swift
//
//
//  Created by Ricky Dall'Armellina on 8/5/23.
//

import Foundation
import Vapor

extension MCServer {
    struct Stats: Content {
        /// CPU usage for the server process
        let cpuPercent: Double
        /// Memory usage (bytes) for the server process
        let memoryUsageBytes: UInt
        
        init(cpuPercent: Double, memoryUsage: UInt) {
            self.cpuPercent = cpuPercent
            self.memoryUsageBytes = memoryUsage
        }
    }
}

// MARK: - Codable

extension MCServer.Stats: Codable {
    private enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case memoryUsageBytes = "memory_usage"
    }
}
