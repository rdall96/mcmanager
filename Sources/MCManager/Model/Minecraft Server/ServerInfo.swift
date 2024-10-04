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
        /// If true, this server needs a restart in order to apply all updated configurations
        let needsRestart: Bool
        /// List of currently active players on the server
//        let onlinePlayers: [String]
        
        init(
            status: Status,
            needsRestart: Bool,
            onlinePlayers: [String]
        ) {
            self.status = status
            self.needsRestart = needsRestart
//            self.onlinePlayers = onlinePlayers
        }
    }
}

// MARK: - Codable

extension MCServer.Info: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
        case needsRestart = "needs_restart"
//        case onlinePlayers = "online_players"
    }
}
