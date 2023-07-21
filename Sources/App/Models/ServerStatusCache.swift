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
        case data
    }
    
    @ID(key: .id)
    // same as the server id
    var id: UUID?
    
    @Field(key: FieldKeys.expiresAt.rawValue)
    var expiresAt: Date
    
    @Field(key: FieldKeys.data.rawValue)
    var data: String
    
    init() {}
    
    init(
        id: UUID,
        ttl: UInt,
        data: MCManager_Shared.Server.Info
    ) {
        self.id = id
        self.expiresAt = .now.addingTimeInterval(Double(ttl))
        self.data = (try? JSONEncoder().encode(data).base64EncodedString()) ?? ""
    }
    
    var isExpired: Bool {
        expiresAt < .now
    }
    
    var serverInfo: MCManager_Shared.Server.Info? {
        guard let data = Data(base64Encoded: self.data) else {
            return nil
        }
        return try? JSONDecoder().decode(MCManager_Shared.Server.Info.self, from: data)
    }
}
