//
//  SettingsController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent
import Vapor

struct SettingsController: MCManagerAPIRoute, RouteCollection {
    static var supportedAPIVersion: APIVersion { .v1 }
    
    let logger: Logger
    /// Callback to execute when the settings are updated
    let onUpdate: (Settings) -> Void
    
    func boot(routes: RoutesBuilder) throws {
        let settings = routes
            .requireAuthentication()
            .apiVersion(.v1)
            .grouped("settings")
        settings.get(use: `get`)
        settings.put(use: update)
    }
    
    // MARK: - Routes
    
    func get(req: Request) async throws -> Settings {
        guard try await req.userHasPermissions(for: .readSettings) else {
            throw Abort(.unauthorized)
        }
        let all = try await Settings.query(on: req.db).all()
        return all.first ?? .defaults
    }
    
    func update(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .editSettings) else {
            throw Abort(.unauthorized)
        }
        // check if the given settigns are valid
        let settings = try req.content.decode(Settings.self)
        // delete all other entries
        for item in try await Settings.query(on: req.db).all() {
            try await item.delete(on: req.db)
            // if we changed the server status cache ttl, we need to expire the existing caches
            if item.serverStatusCacheTTLSeconds != settings.serverStatusCacheTTLSeconds {
                try await ServerStatusCache.query(on: req.db).all()
                    .delete(on: req.db)
            }
        }
        // save the new settings (this will create a DB entry if it doesn't exist)
        try await settings.save(on: req.db)
        onUpdate(settings)
        logger.notice("Updated MCManager server settings, a restart might be required")
        return .ok
    }
}
