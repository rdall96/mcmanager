// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "MCManager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Vapor + Fluent (SQLite)
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.4"),
        .package(url: "https://github.com/vapor/multipart-kit.git", from: "4.7.1"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.1.2"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.13.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.9.0"),
        // OAS generation
        .package(url: "https://github.com/dankinsoid/VaporToOpenAPI.git", from: "4.9.2"),
        // Apple libraries
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.0"),
        // Docker API
        .package(url: "https://gitlab.com/rdall96/docker-swift-api", from: "1.3.0"),
        // Utilities
        .package(url: "https://github.com/qiuzhifei/swift-commands", from: "0.6.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
    ],
    targets: [
        .executableTarget(
            name: "MCManager",
            dependencies: [
                .product(name: "Commands", package: "swift-commands"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "DockerSwiftAPI", package: "docker-swift-api"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://www.swift.org/server/guides/building.html#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),

                // Required by Vapor 4.121.4
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("ImmutableWeakCaptures"),
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
