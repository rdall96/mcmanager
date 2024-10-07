import Fluent
import Vapor
import Logging

func routes(_ app: Application) async throws {
    let logger = Logger(label: "mcmanager.setup")
    
    // App version endpoint
    app.get("version") { _ async in
        AppVersion.latest.description
    }
    
    // Authentication
    let authController = AuthenticationController()
    try app.register(collection: authController)
    
    // API
    let api = try await API(database: app.db)
    try app.register(collection: api)
    
    #if DEBUG
    let registeredRoutes = app.routes.all.compactMap { "  \($0.description)" }
    let registeredRoutesList = registeredRoutes.joined(separator: "\n")
    logger.info("Registered \(registeredRoutes.count) route(s):\n\(registeredRoutesList)")
    #endif // DEBUG
}

// MARK: - API routes

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

fileprivate struct API: MCManagerAPIRoute, RouteCollection {
    
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
