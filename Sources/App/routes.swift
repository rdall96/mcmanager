import Fluent
import Vapor
import MCManager_Shared

func routes(_ app: Application) async throws {
    // create the parent API endpoint
    let api = try API(version: .current)
    
    // attempt to load the existing servers
    try await api.serverController.loadExistingServers(from: app.db)
    try app.register(collection: api)
}

// MARK: - API routes
fileprivate struct API: RouteCollection {
    
    let version: Version
    let settingsController: SettingsController
    let authenticationController: AuthenticationController
    let userController: UserController
    let serverController: ServerController
    
    init(version: Version) throws {
        self.version = version
        settingsController = SettingsController { _ in
            // Do any necessary updates that depend on the settings
        }
        authenticationController = AuthenticationController()
        userController = UserController()
        serverController = try ServerController(
            serversPath: try DirectoryConfiguration.detect().serversPath
        )
    }
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        
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
