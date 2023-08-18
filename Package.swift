// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "MCManager",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        // Web framework: Vapor
        .package(url: "https://github.com/vapor/vapor.git", from: "4.76.0"),
        // SQLite database management
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        // JWT for authentication
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.2"),
        // Docker api
        .package(url: "https://gitlab.com/rdall96/docker-swift-api", from: "1.2.0"),
        // Swift commands
        .package(url: "https://github.com/qiuzhifei/swift-commands", from: "0.6.0"),
    ],
    targets: [
        
        // Shared data model
        .target(
            name: "MCManager-Shared",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ],
            path: "Sources/Shared"
        ),
        .testTarget(
            name: "MCManager-SharedTests",
            dependencies: [
                .target(name: "MCManager-Shared"),
            ],
            path: "Tests/SharedTests"
        ),
        
        // Minecraft runtime (mcmanager-core)
        .target(
            name: "MinecraftRuntime",
            dependencies: [
                .target(name: "MCManager-Shared"),
                .product(name: "DockerSwiftAPI", package: "docker-swift-api"),
                .product(name: "Commands", package: "swift-commands"),
            ]
        ),
        .testTarget(
            name: "MinecraftRuntimeTests",
            dependencies: [
                .target(name: "MinecraftRuntime"),
            ]
        ),
        
        // Web server
        .executableTarget(
            name: "MCManager",
            dependencies: [
                .target(name: "MCManager-Shared"),
                .target(name: "MinecraftRuntime"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Commands", package: "swift-commands"),
            ],
            path: "Sources/App",
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://www.swift.org/server/guides/building.html#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "MCManagerTests",
            dependencies: [
                .target(name: "MCManager"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests/AppTests"
        )
    ]
)
