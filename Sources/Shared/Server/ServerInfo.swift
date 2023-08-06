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
        
        @_spi(MCManager_Runtime)
        public init(
            status: Status,
            onlinePlayers: [String]
        ) {
            self.status = status
            self.onlinePlayers = onlinePlayers
        }
    }
}

extension Server.Info: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
        case onlinePlayers = "online_players"
    }
}
