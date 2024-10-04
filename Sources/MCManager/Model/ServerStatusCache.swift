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
        case expiresAt = "expires_at"
        case infoData = "info"
        case metricsData = "metrics"
        case statsData = "stats"
    }
    
    @ID(key: .id)
    // same as the server id
    var id: UUID?
    
    @Field(key: FieldKeys.expiresAt.rawValue)
    var expiresAt: Date
    
    @Field(key: FieldKeys.infoData.rawValue)
    private var infoData: Data?
    
    @Field(key: FieldKeys.statsData.rawValue)
    private var statsData: Data?
    
    init() {}
    
    init(
        id: UUID,
        ttl: UInt,
        info: MCServer.Info,
        stats: MCServer.Stats
    ) {
        self.id = id
        self.expiresAt = .now.addingTimeInterval(Double(ttl))
        self.infoData = try? JSONEncoder().encode(info)
        self.statsData = try? JSONEncoder().encode(stats)
    }
    
    var isExpired: Bool { expiresAt < .now }
    
    /// Cached `Server.Info` value
    var info: MCServer.Info? {
        guard let infoData else { return nil }
        return try? JSONDecoder().decode(MCServer.Info.self, from: infoData)
    }
    
    /// Cached `Server.Metrics` value
    var stats: MCServer.Stats? {
        guard let statsData else { return nil }
        return try? JSONDecoder().decode(MCServer.Stats.self, from: statsData)
    }
}
