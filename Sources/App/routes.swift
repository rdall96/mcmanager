import Fluent
import Vapor
import MCManager_Shared

func routes(_ app: Application) async throws {
    // load the system settings
    let settings = try await Settings.query(on: app.db).all().first ?? .defaults
    // create the parent API endpoint
    let api = try API(settings: settings)
    
    // attempt to load the existing servers
    try await api.serverController.loadExistingServers(from: app.db)
    try app.register(collection: api)
}

// MARK: - API routes
fileprivate struct API: RouteCollection {
    
    let settings: Settings
    let serverController: ServerController
    
    init(settings: Settings) throws {
        self.settings = settings
        let serversPath = try DirectoryConfiguration.detect().serversPath
        serverController = try ServerController(serversPath: serversPath, settings: settings)
    }
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        
        // Register all API routes
        
        // version
        api.get("version") { _ async in
            Version.current.description
        }
        
        // settings
        let settingsController = SettingsController() { newSettings in
            // TODO: Update server routes with new settings
        }
        try api.register(collection: settingsController)
        
        // users
        try api.register(collection: UserController())
        
        // servers
        try api.register(collection: serverController)
    }
}
