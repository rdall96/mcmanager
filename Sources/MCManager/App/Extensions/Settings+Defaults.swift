//
//  Settings+Defaults.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/11/24.
//

extension Settings {
    static var defaults: Settings {
        .init(
            serverStatusCacheTTLSeconds: 5,
            allowedServerPorts: "\(Settings.validPortRange.lowerBound)-\(Settings.validPortRange.upperBound)",
            maxRunningServers: 10
        )
    }
}
