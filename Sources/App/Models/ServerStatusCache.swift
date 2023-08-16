//
//  ServerStatusCache.swift
//
//
//  Created by Ricky Dall'Armellina on 7/21/23.
//

import Fluent
import Vapor
import MCManager_Shared

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
    var infoData: Data?
    
    @Field(key: FieldKeys.metricsData.rawValue)
    var metricsData: Data?
    
    init() {}
    
    init(
        id: UUID,
        ttl: UInt,
        info: MCManager_Shared.Server.Info,
        metrics: MCManager_Shared.Server.Metrics
    ) {
        self.id = id
        self.expiresAt = .now.addingTimeInterval(Double(ttl))
        self.infoData = try? JSONEncoder().encode(info)
        self.metricsData = try? JSONEncoder().encode(metrics)
    }
    
    var isExpired: Bool {
        expiresAt < .now
    }
    
    /// Cached `Server.Info` value
    var info: MCManager_Shared.Server.Info? {
        guard let infoData else { return nil }
        return try? JSONDecoder().decode(MCManager_Shared.Server.Info.self, from: infoData)
    }
    
    /// Cached `Server.Metrics` value
    var metrics: MCManager_Shared.Server.Metrics? {
        guard let metricsData else { return nil }
        return try? JSONDecoder().decode(MCManager_Shared.Server.Metrics.self, from: metricsData)
    }
}
