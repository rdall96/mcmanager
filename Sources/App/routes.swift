import Fluent
import Vapor
import Shared

func routes(_ app: Application) throws {
    try app.register(collection: API())
}

// MARK: - API routes
fileprivate struct API: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        
        // Register all API routes
        
        // version
        api.get("version") { _ async in
            Version.current.description
        }
        
        try api.register(collection: UserController())
        try api.register(collection: ServerController())
    }
}
