//
//  API.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/8/24.
//

import Fluent
import Vapor

protocol MCManagerAPIRoute: Sendable {
    var logger: Logger { get }
}

extension MCManagerAPIRoute {

    @discardableResult
    func requireAuthenticated(for req: Request) throws -> User {
        do {
            return try req.auth.require(User.self)
        }
        catch {
            throw AuthenticationError.notAuthenticated
        }
    }

    @discardableResult
    func requireAdmin(for req: Request) throws -> User {
        let user = try requireAuthenticated(for: req)
        guard user.isAdmin else {
            throw UserError.unauthorized
        }
        return user
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
        
        settingsController = SettingsController(logger: logger)
        userController = UserController(logger: logger)
        roleController = RoleController(logger: logger)
        serverController = try await ServerController(
            serversPath: try DirectoryConfiguration.detect().serversPath,
            database: database,
            logger: logger
        )
    }
    
    func boot(routes: any RoutesBuilder) throws {
        let api = routes.grouped("api")
            .openAPIMetadata()

        try api.register(collection: settingsController)
        try api.register(collection: userController)
        try api.register(collection: roleController)
        try api.register(collection: serverController)
    }
}
