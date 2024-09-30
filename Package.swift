// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "MCManager",
    platforms: [
        .macOS(.v13)
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
        .package(url: "https://gitlab.com/rdall96/docker-swift-api", from: "1.3.0"),
        // Swift commands
        .package(url: "https://github.com/qiuzhifei/swift-commands", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "MCManager",
            dependencies: [
                .product(name: "Commands", package: "swift-commands"),
                .product(name: "DockerSwiftAPI", package: "docker-swift-api"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Vapor", package: "vapor"),
            ],
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
            swiftSettings: [
                .define("MCMANAGER_TESTS"),
            ]
        )
    ]
)
