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
    func boot(routes: RoutesBuilder) throws {
        let settings = routes.grouped("settings")
        settings.get(use: `get`)
        settings.put(use: update)
    }
    
    func get(req: Request) async throws -> Settings {
        try await Settings.query(on: req.db).first() ?? .defaults
    }
    
    func update(req: Request) async throws -> Settings {
        // check if the given settigns are valid
        guard let settings = try? req.content.decode(Settings.self) else {
            throw Abort(.badRequest)
        }
        // Save the new settings (this will create a DB entry if it doesn't exist)
        try await settings.save(on: req.db)
        return settings
    }
}
