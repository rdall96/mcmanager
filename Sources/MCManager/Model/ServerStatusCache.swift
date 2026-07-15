//
//  ServerStatusCache.swift
//
//
//  Created by Ricky Dall'Armellina on 7/21/23.
//

import Fluent
import Vapor

final class ServerStatusCache: Model, Content {
    static let schema = "server_status_cache"
    
    enum FieldKeys: FieldKey {
        case createdAt = "created_at"
        case infoData = "info"
        case metricsData = "metrics"
        case statsData = "stats"
    }
    
    @ID(key: .id)
    // same as the server id
    var id: UUID?

    @Field(key: FieldKeys.createdAt.rawValue)
    var createdAt: Date

    @Field(key: FieldKeys.infoData.rawValue)
    private var infoData: Data?
    
    @Field(key: FieldKeys.statsData.rawValue)
    private var statsData: Data?
    
    init() {}
    
    init(
        id: UUID,
        createdAt: Date = .now,
        info: MinecraftServer.Info,
        stats: MinecraftServer.Stats
    ) {
        self.id = id
        self.createdAt = createdAt
        self.infoData = try? JSONEncoder().encode(info)
        self.statsData = try? JSONEncoder().encode(stats)
    }
    
    /// Cached `Server.Info` value
    var info: MinecraftServer.Info? {
        guard let infoData else { return nil }
        return try? JSONDecoder().decode(MinecraftServer.Info.self, from: infoData)
    }
    
    /// Cached `Server.Metrics` value
    var stats: MinecraftServer.Stats? {
        guard let statsData else { return nil }
        return try? JSONDecoder().decode(MinecraftServer.Stats.self, from: statsData)
    }
}
