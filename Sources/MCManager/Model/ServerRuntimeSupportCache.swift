//
//  ServerRuntimeSupportCache.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 11/8/25.
//

import Foundation
import Fluent
import Vapor

final class ServerRuntimeSupportCache: Model, Content {
    static let schema = "runtime_support"

    enum FieldKeys: FieldKey {
        case createdAt = "created_at"
        case serverType = "server_type"
        case versions
    }

    @ID(key: .id)
    // unused field
    internal var id: UUID?

    @Field(key: FieldKeys.createdAt.rawValue)
    var createdAt: Date

    @Field(key: FieldKeys.serverType.rawValue)
    var serverType: MCServer.ServerType

    @Field(key: FieldKeys.versions.rawValue)
    var versions: [String]

    init() {}

    init(with runtimeSupport: MCServer.RuntimeSupport) {
        id = UUID()
        createdAt = .now
        serverType = runtimeSupport.type
        versions = runtimeSupport.versions.map { $0.description }
    }
}

extension MCServer.RuntimeSupport {
    init(with cache: ServerRuntimeSupportCache) {
        self.init(type: cache.serverType, versions: cache.versions)
    }
}
