//
//  Settings.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent
import Vapor
import MCManager_Shared

extension Settings: Content {}

extension Settings {
    static var defaults: Settings {
        .init(
            serverStatusTTLSeconds: 5,
            allowedServerPorts: "\(Settings.validPortRange.lowerBound)-\(Settings.validPortRange.upperBound)"
        )
    }
    
    /// If the server status cache is enabled
    var serverStatusCacheIsEnabled: Bool { serverStatusTTLSeconds > 0 }
}
