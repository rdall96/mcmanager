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
    }
    
    @ID(key: .id)
    // same as the server id
    var id: UUID?
    
    @Field(key: FieldKeys.expiresAt.rawValue)
    var expiresAt: Date
    
    @Field(key: FieldKeys.infoData.rawValue)
    private var infoData: Data?
    
    @Field(key: FieldKeys.metricsData.rawValue)
    private var metricsData: Data?
    
    init() {}
    
    init(
        id: UUID,
        ttl: UInt,
        info: MCServer.Info,
        metrics: MCServer.Metrics
    ) {
        self.id = id
        self.expiresAt = .now.addingTimeInterval(Double(ttl))
        self.infoData = try? JSONEncoder().encode(info)
        self.metricsData = try? JSONEncoder().encode(metrics)
    }
    
    var isExpired: Bool { expiresAt < .now }
    
    /// Cached `Server.Info` value
    var info: MCServer.Info? {
        guard let infoData else { return nil }
        return try? JSONDecoder().decode(MCServer.Info.self, from: infoData)
    }
    
    /// Cached `Server.Metrics` value
    var metrics: MCServer.Metrics? {
        guard let metricsData else { return nil }
        return try? JSONDecoder().decode(MCServer.Metrics.self, from: metricsData)
    }
}
