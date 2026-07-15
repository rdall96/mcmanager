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
            serverSupportCacheTTLSeconds: 3600, // 1 hour
            allowedServerPorts: "\(MinecraftServer.Port.validPortRange.lowerBound)-\(MinecraftServer.Port.validPortRange.upperBound)",
            maxRunningServers: 10
        )
    }
}
