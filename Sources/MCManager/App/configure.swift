import NIOSSL
import Fluent
import FluentSQLiteDriver
import JWT
import Vapor

fileprivate let defaultAPIPort: Int = 8000

// configures your application
public func configure(_ app: Application) async throws {
    // Server name
    app.http.server.configuration.serverName = "MCManager"
    
    // Application port
    var apiPort = defaultAPIPort
    if let apiPortValue = Environment.get("API_PORT"),
       let customAPIPort = Int(apiPortValue) {
        apiPort = customAPIPort
    }
    app.http.server.configuration.port = apiPort
    
    // Password encryption
    app.passwords.use(.bcrypt(cost: 16))
    
    // Setup database
    try connectDatabase(app)
    try await migrateDatabase(app)
    try await firstTimeSetup(app)
    
    // Security
    try await setupKeys(app)

    // Add error middleware
    app.middleware.use(ApplicationErrorMiddleware())

    // Add CORS (unused)
    // cors middleware should come before any error middleware using `at: .beginning`
    app.middleware.use(WebAppCORSMiddleware(), at: .beginning)
    
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
    Permissions.migrations.forEach { app.migrations.add($0) }
    Role.migrations.forEach { app.migrations.add($0) }
    User.migrations.forEach { app.migrations.add($0) }
    SessionToken.migrations.forEach { app.migrations.add($0) }
    MinecraftServer.migrations.forEach { app.migrations.add($0) }
    ServerStatusCache.migrations.forEach { app.migrations.add($0) }
    ServerRuntimeSupportCache.migrations.forEach { app.migrations.add($0) }

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
        app.logger.notice("Creating admin user")
        let admin = try User.createSuperAdmin(password: "mcmanager")
        try await admin.save(on: app.db)
    }

    // If there are no default permissions, add them
    if try await Permissions.defaults(on: app.db) == nil {
        app.logger.notice("Setting default user permissions")
        try await Permissions.defaults.save(on: app.db)
    }
}

// MARK: - Key signing and security

fileprivate func setupKeys(_ app: Application) async throws {
    let privateKeyPath = try app.directory.privateKeyPath
    if !FileManager.default.fileExists(atPath: privateKeyPath.path) {
        app.logger.notice("Generating private key")
        try await app.directory.generateKeys(at: privateKeyPath)
    }
    let key = try String(contentsOfFile: privateKeyPath.path)
    let keySigner = JWTSigner.hs256(key: key)
    app.jwt.signers.use(keySigner, kid: .private, isDefault: true)
}

extension JWKIdentifier {
    static let `public` = JWKIdentifier(string: "public")
    static let `private` = JWKIdentifier(string: "private")
}
