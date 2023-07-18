import Fluent
import Vapor
import MCManager_Shared

func routes(_ app: Application) async throws {
    let settings = try await Settings.find(nil, on: app.db) ?? .defaults
    try app.register(collection: API(settings: settings))
}

// MARK: - API routes
fileprivate struct API: RouteCollection {
    
    let settings: Settings
    
    init(settings: Settings) {
        self.settings = settings
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
        let serversPath = try DirectoryConfiguration.detect().serversPath
        let serverController = try ServerController(serversPath: serversPath, settings: settings)
        try api.register(collection: serverController)
    }
}
