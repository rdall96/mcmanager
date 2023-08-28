import Fluent
import Vapor
import MCManager_Shared
import Logging

func routes(_ app: Application) async throws {
    // create the parent API endpoint
    let api = try API(version: .current)
    
    // attempt to load the existing servers
    try await api.serverController.loadExistingServers(from: app.db)
    try app.register(collection: api)
}

// MARK: - API routes

protocol MCManagerAPIRoute {
    var logger: Logger { get }
}

fileprivate struct API: MCManagerAPIRoute, RouteCollection {
    
    let version: Version
    let logger: Logger
    let settingsController: SettingsController
    let authenticationController: AuthenticationController
    let userController: UserController
    let serverController: ServerController
    
    init(version: Version) throws {
        self.version = version
        let logger = Logger(label: "mcmanager.api")
        self.logger = logger
        settingsController = SettingsController(
            logger: logger,
            onUpdate: { _ in
                // Do any necessary updates that depend on the settings
            }
        )
        authenticationController = AuthenticationController(logger: logger)
        userController = UserController(logger: logger)
        serverController = try ServerController(
            serversPath: try DirectoryConfiguration.detect().serversPath,
            logger: logger
        )
        
        logger.notice("API version: \(version.description)")
    }
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        logger.info("Setting up API routes")
        
        // Register all API routes
        api.get("version") { _ async in
            version.description
        }
        try api.register(collection: authenticationController)
        try api.register(collection: settingsController)
        try api.register(collection: userController)
        try api.register(collection: serverController)
    }
}
