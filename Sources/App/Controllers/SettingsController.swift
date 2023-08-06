//
//  SettingsController.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Fluent
import Vapor
import MCManager_Shared

struct SettingsController: RouteCollection {
    
    /// Callback to execute when the settings are updated
    let onUpdate: (Settings) -> Void
    
    func boot(routes: RoutesBuilder) throws {
        let settings = routes
            .grouped(SessionToken.Authenticator())
            .grouped(User.guardMiddleware())
            .grouped("settings")
        settings.get(use: `get`)
        settings.put(use: update)
    }
    
    // MARK: - Helpers
    
    private func checkPermissions(for req: Request) throws {
        guard try req.auth.require(User.self).isAdmin else {
            throw Abort(.unauthorized)
        }
    }
    
    private func expireServerStatusCaches(on database: Database) async throws {
        for cache in try await ServerStatusCache.query(on: database).all() {
            try await cache.delete(on: database)
        }
    }
    
    // MARK: - Routes
    
    func get(req: Request) async throws -> Settings {
        let all = try await Settings.query(on: req.db).all()
        return all.first ?? .defaults
    }
    
    func update(req: Request) async throws -> HTTPStatus {
        // only admins can edit settings
        try checkPermissions(for: req)
        // check if the given settigns are valid
        let settings = try req.content.decode(Settings.self)
        // delete all other entries
        for item in try await Settings.query(on: req.db).all() {
            try await item.delete(on: req.db)
            // if we changed the server status cache ttl, we need to expire the existing caches
            if item.serverStatusCacheTTLSeconds != settings.serverStatusCacheTTLSeconds {
                try await expireServerStatusCaches(on: req.db)
            }
        }
        // save the new settings (this will create a DB entry if it doesn't exist)
        try await settings.save(on: req.db)
        onUpdate(settings)
        return .ok
    }
}
