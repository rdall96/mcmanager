import NIOSSL
import Fluent
import FluentSQLiteDriver
import JWT
import Vapor
import MCManager_Shared

extension JWKIdentifier {
    static let `public` = JWKIdentifier(string: "public")
    static let `private` = JWKIdentifier(string: "private")
}

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Password encryption
    app.passwords.use(.bcrypt(cost: 16))
    
    // Setup database
    try connectDatabase(app)
    try await migrateDatabase(app)
    try await firstTimeSetup(app)
    
    // Security
//    try setupKeys(app)
    
    // Register routes
    try await routes(app)
}

fileprivate func setupKeys(_ app: Application) throws {
    let privateKeyPath = try app.directory.privateKeyPath
    if !FileManager.default.fileExists(atPath: privateKeyPath.path) {
        app.directory.generateKeys(at: privateKeyPath)
    }
    let privateKey = try String(contentsOfFile: privateKeyPath.path)
    let privateSigner = try JWTSigner.rs256(key: .private(pem: privateKey.bytes))
    
    let publicKey = try String(contentsOfFile: try app.directory.publicKeyPath.path)
    let publicSigner = try JWTSigner.rs256(key: .public(pem: publicKey.bytes))
    
    app.jwt.signers.use(privateSigner, kid: .private)
    app.jwt.signers.use(publicSigner, kid: .public, isDefault: true)
}

extension String {
    fileprivate var bytes: [UInt8] { .init(self.utf8) }
}

fileprivate func connectDatabase(_ app: Application) throws {
    do {
        let databasePath = try DirectoryConfiguration.detect().defaultDatabasePath
        app.databases.use(
            .sqlite(.file(databasePath.path)),
            as: .sqlite,
            isDefault: true
        )
        app.logger.info("Connected database at: \(databasePath)")
    }
    catch {
        app.logger.error("Failed to connect database!")
        throw error
    }
}

fileprivate func migrateDatabase(_ app: Application) async throws {
    // Add database migrations
    app.migrations.add(Settings.Migration())
    app.migrations.add(User.Migration())
    app.migrations.add(SessionToken.Migration())
    app.migrations.add(Server.Migration())
    
    // Migrate database
    try await app.autoMigrate()
}

/// Perform the first time setup for the app. i.e.: create the default admin user
fileprivate func firstTimeSetup(_ app: Application) async throws {
    // If there's no admin user, create one
    let admin = User.admin
    if try await User.find(admin.id, on: app.db) == nil {
        try await admin.save(on: app.db)
    }
    
    // Write default settings
    if try await Settings.query(on: app.db).all().isEmpty {
        try await Settings.defaults.save(on: app.db)
    }
}
