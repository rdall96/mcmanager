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
        let settings = routes.grouped("settings")
        settings.get(use: `get`)
        settings.put(use: update)
    }
    
    func get(req: Request) async throws -> Settings {
        let all = try await Settings.query(on: req.db).all()
        return all.first ?? .defaults
    }
    
    func update(req: Request) async throws -> HTTPStatus {
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
