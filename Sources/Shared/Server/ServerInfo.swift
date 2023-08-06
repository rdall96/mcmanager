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
        /// List of currently active players on the server
        public let onlinePlayers: [String]
        /// Maximum number of players allowed on this server
        public let maximumPlayerCount: UInt
        
        @_spi(MCManager_Runtime)
        public init(
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

extension Server.Info: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
        case onlinePlayers = "online_players"
        case maximumPlayerCount = "maximum_player_count"
    }
}
