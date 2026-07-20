//
//  ServerRuntimeSupportCache.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 11/8/25.
//

import Foundation
import Fluent
import Vapor

final class ServerRuntimeSupportCache: Model, Content, @unchecked Sendable {
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
    var serverType: MinecraftServer.ServerType

    @Field(key: FieldKeys.versions.rawValue)
    var versions: [String]

    init() {}

    init(with runtimeSupport: MinecraftServer.RuntimeSupport) {
        id = UUID()
        createdAt = .now
        serverType = runtimeSupport.type
        versions = runtimeSupport.versions.map { $0.description }
    }
}

extension MinecraftServer.RuntimeSupport {
    init(with cache: ServerRuntimeSupportCache) {
        self.init(type: cache.serverType, versions: cache.versions)
    }
}
