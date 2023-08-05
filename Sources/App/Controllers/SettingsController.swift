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
        let user = try req.auth.require(User.self)
        // only admins can view/edit settings
        guard user.isAdmin else {
            throw Abort(.unauthorized)
        }
    }
    
    // MARK: - Routes
    
    func get(req: Request) async throws -> Settings {
        try checkPermissions(for: req)
        let all = try await Settings.query(on: req.db).all()
        return all.first ?? .defaults
    }
    
    func update(req: Request) async throws -> HTTPStatus {
        try checkPermissions(for: req)
        // check if the given settigns are valid
        let settings = try req.content.decode(Settings.self)
        // delete all other entries
        for item in try await Settings.query(on: req.db).all() {
            try await item.delete(on: req.db)
        }
        // save the new settings (this will create a DB entry if it doesn't exist)
        try await settings.save(on: req.db)
        onUpdate(settings)
        return .ok
    }
}
