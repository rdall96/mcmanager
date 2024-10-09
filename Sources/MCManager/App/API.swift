//
//  API.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/8/24.
//

import Vapor
import Fluent

protocol MCManagerAPIRoute {
    var logger: Logger { get }
}

extension MCManagerAPIRoute {
    func requireAdmin(for req: Request) throws {
        guard try req.auth.require(User.self).isAdmin else {
            throw Abort(.unauthorized)
        }
    }
}

struct API: MCManagerAPIRoute, RouteCollection {
    
    let logger: Logger
    
    // Controllers
    let settingsController: SettingsController
    let userController: UserController
    let roleController: RoleController
    let serverController: ServerController
    
    init(database: any Database) async throws {
        let logger = Logger(label: "mcmanager.api")
        self.logger = logger
        
        settingsController = SettingsController(
            logger: logger,
            onUpdate: { _ in
                // Do any necessary updates that depend on the settings
            }
        )
        userController = UserController(logger: logger)
        roleController = RoleController(logger: logger)
        serverController = try await ServerController(
            serversPath: try DirectoryConfiguration.detect().serversPath,
            database: database,
            logger: logger
        )
    }
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        
        try api.register(collection: settingsController)
        try api.register(collection: userController)
        try api.register(collection: roleController)
        try api.register(collection: serverController)
    }
}
