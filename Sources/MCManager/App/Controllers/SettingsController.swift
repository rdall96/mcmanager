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
        try await Settings.query(on: req.db).first() ?? .defaults
    }
    
    func update(req: Request) async throws -> HTTPStatus {
        guard try await req.userHasPermissions(for: .editSettings) else {
            throw Abort(.unauthorized)
        }
        let settings = try req.content.decode(Settings.self)
        
        // delete all other entries
        let existingSettings = try await Settings.query(on: req.db).all()
        try await existingSettings.delete(on: req.db)
        
        // if we changed the server status cache ttl, we need to expire the existing caches
        let serverStatusTTLChanged = !existingSettings.filter {
            $0.serverStatusCacheTTLSeconds != settings.serverStatusCacheTTLSeconds
        }.isEmpty
        if serverStatusTTLChanged {
            try await ServerStatusCache.query(on: req.db).delete()
        }
        
        // save the new settings (this will create a DB entry if it doesn't exist)
        try await settings.save(on: req.db)
        logger.notice("Updated MCManager application settings, a restart might be required")
        
        // notify listeners
        onUpdate(settings)
        
        return .ok
    }
}
