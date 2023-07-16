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
    ],
    targets: [
        // Shared data model
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]
        ),
        .testTarget(name: "SharedTests", dependencies: [
            .target(name: "Shared")
        ]),
        // Tools & utilities
        .target(
            name: "Utilities",
            dependencies: []
        ),
        .testTarget(name: "UtilitiesTests", dependencies: [
            .target(name: "Utilities")
        ]),
        // Web server
        .executableTarget(
            name: "App",
            dependencies: [
                .target(name: "Shared"),
                .target(name: "Utilities"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://www.swift.org/server/guides/building.html#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
