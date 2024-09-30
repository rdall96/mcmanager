//
//  ServerInfo.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor

extension MCServer {
    struct Info: Content {
        /// Current status of the server
        let status: Status
        /// List of currently active players on the server
        let onlinePlayers: [String]
        /// Maximum number of players allowed on this server
        let maximumPlayerCount: UInt
        
        init(
            status: Status,
            onlinePlayers: [String],
            maximumPlayerCount: UInt
        ) {
            self.status = status
            self.onlinePlayers = onlinePlayers
            self.maximumPlayerCount = maximumPlayerCount
        }
    }
}

// MARK: - Codable

extension MCServer.Info: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
        case onlinePlayers = "online_players"
        case maximumPlayerCount = "maximum_player_count"
    }
}
