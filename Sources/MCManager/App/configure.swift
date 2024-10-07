import NIOSSL
import Fluent
import FluentSQLiteDriver
import JWT
import Vapor

fileprivate let applicationHTTPPort: Int = 3000

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Server name
    app.http.server.configuration.serverName = "MCManager"
    
    // Application port
    app.http.server.configuration.port = applicationHTTPPort
    
    // Password encryption
    app.passwords.use(.bcrypt(cost: 16))
    
    // Setup database
    try connectDatabase(app)
    try await migrateDatabase(app)
    try await firstTimeSetup(app)
    
    // Security
    try await setupKeys(app)
    
    // Add CORS
    addCorsMiddleware(to: app)
    
    // Register routes
    try await routes(app)
}

// MARK: - Database

fileprivate func connectDatabase(_ app: Application) throws {
    do {
        let databasePath = try app.directory.defaultDatabasePath
        app.databases.use(
            .sqlite(.file(databasePath.path)),
            as: .sqlite,
            isDefault: true
        )
        app.logger.info("Connected database at: \(databasePath.path)")
    }
    catch {
        app.logger.error("Failed to connect database!")
        throw error
    }
}

fileprivate func migrateDatabase(_ app: Application) async throws {
    // Add database migrations
    Settings.migrations.forEach { app.migrations.add($0) }
    User.migrations.forEach { app.migrations.add($0) }
    SessionToken.migrations.forEach { app.migrations.add($0) }
    MCServer.migrations.forEach { app.migrations.add($0) }
    ServerStatusCache.migrations.forEach { app.migrations.add($0) }
    
    // Migrate database
    try await app.autoMigrate()
}

/// Perform the first time setup for the app. i.e.: create the default admin user
fileprivate func firstTimeSetup(_ app: Application) async throws {
    let currentAdmin = try await User.query(on: app.db)
        .filter(\User.$username, .equal, User.superAdminUsername)
        .first()
    
    if currentAdmin == nil {
        // If there's no admin user, create one
        let admin = try User.createSuperAdmin(password: "mcmanager")
        try await admin.save(on: app.db)
    }
    
    // Write default settings
    if try await Settings.query(on: app.db).all().isEmpty {
        try await Settings.defaults.save(on: app.db)
    }
}

// MARK: - Key signing and security

fileprivate func setupKeys(_ app: Application) async throws {
    let privateKeyPath = try app.directory.privateKeyPath
    if !FileManager.default.fileExists(atPath: privateKeyPath.path) {
        await app.directory.generateKeys(at: privateKeyPath)
    }
    let key = try String(contentsOfFile: privateKeyPath.path)
    let keySigner = JWTSigner.hs256(key: key)
    app.jwt.signers.use(keySigner, kid: .private, isDefault: true)
}

extension JWKIdentifier {
    static let `public` = JWKIdentifier(string: "public")
    static let `private` = JWKIdentifier(string: "private")
}

// MARK: - Middleware

fileprivate func addCorsMiddleware(to app: Application) {
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .defaultFrontend,
        allowedMethods: [.GET, .POST, .PUT, .DELETE],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin],
        allowCredentials: true
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    // cors middleware should come before default error middleware using `at: .beginning`
    app.middleware.use(cors, at: .beginning)
}

extension CORSMiddleware.AllowOriginSetting {
    static var defaultFrontend: Self {
        .any([
            "127.0.0.1:\(applicationHTTPPort)",
            "http://localhost:\(applicationHTTPPort)"
        ])
    }
}
