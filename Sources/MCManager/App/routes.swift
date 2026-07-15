import Fluent
import Vapor
import Logging

func routes(_ app: Application) async throws {
    let logger = Logger(label: "mcmanager.setup")
    
    // App version endpoint
    app.get("version") { _ in
        AppVersion.latest.description
    }
    .openAPIMetadata(
        summary: "Fetch the MCManager app version.",
        tag: .application,
        responses: .appVersion
    )

    // Authentication
    let authController = AuthenticationController()
    try app.register(collection: authController)
    
    // API
    let api = try await API(database: app.db)
    try app.register(collection: api)
    
    // OpenAPI
    let openAPIRoutes = OpenAPIRoutes(app)
    try app.register(collection: openAPIRoutes)

    #if DEBUG
    // Print out registered routs
    let registeredRoutes = app.routes.all.compactMap { "  \($0.description)" }
    let registeredRoutesList = registeredRoutes.joined(separator: "\n")
    logger.info("Registered \(registeredRoutes.count) route(s):\n\(registeredRoutesList)")
    #endif // DEBUG
}
