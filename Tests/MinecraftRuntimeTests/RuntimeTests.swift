//
//  RuntimeTests.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

@testable import MinecraftRuntime
import MCManager_Shared
import DockerSwift
import XCTest

final class RuntimeTests: XCTestCase {
    
    var testPath: URL!
    var docker: DockerClient!
    
    override func setUp() async throws {
        // assign a temporary directory
        testPath = FileManager.default.temporaryDirectory
        
        // ensure docker is running
        docker = DockerClient()
        try await docker?.ping()
    }
    
    override func tearDown() async throws {
        // terminate Docker client
        try await docker.shutdown()
    }
    
    // MARK: - Helpers
    
    private static var versions: [String] {
        ["1.5.2", "1.9", "1.12.2", "1.16.4", "1.17.1", "1.19", "1.20.1"]
    }
    
    private static var ports: [UInt16] {
        (25500...25599).map { $0 }
    }
    
    /// Create a server object for testing
    private var server: Server {
        Server(
            name: "Test server",
            type: .java,
            version: Self.versions.randomElement()!,
            port: Self.ports.randomElement()!
        )
    }
    
    // MARK: - Test cases
    
    func testCreateRuntime() async throws {
        let server = server
        let serverPath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertFalse(FileManager.default.fileExists(atPath: serverPath.path))
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        XCTAssertTrue(FileManager.default.fileExists(atPath: serverPath.path))
        let status = await runtime.info.status
        XCTAssertEqual(status, .stopped)
    }
    
    func testNewRuntimeCreatesDefaultConfig() async throws {
        let server = server
        let configPath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(ServerRuntime.configFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configPath.path))
        _ = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
        let data = try Data(contentsOf: configPath)
        let config: [Server.Config] = try JSONDecoder().decode([Server.Config].self, from: data)
        XCTAssertGreaterThan(config.count, 0)
        XCTAssertNotNil(config.first(where: { $0.id == "GAMEMODE" }))
    }
    
    func testUpdateRuntime() async throws {
        let server = server
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        server.port = ServerRuntime.minecraftServerPort
        server.version = Self.versions.randomElement()!
        try await runtime.update(server)
    }
    
    func testUpdateRuntimeInvalid() async throws {
        let server = server
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        server.id = UUID()
        server.version = Self.versions.randomElement()!
        do {
            try await runtime.update(server)
            XCTFail()
        }
        catch {}
    }
    
    func testDeleteRuntime() async throws {
        let server = server
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        let runtimePath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimePath.path))
        try await runtime.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimePath.path))
    }
    
    func testUpdateIcon() async throws {
        let server = server
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        var icon = await runtime.icon
        XCTAssertNil(icon)
        try await runtime.updateIcon(TestData.serverIcon)
        icon = await runtime.icon
        XCTAssertNotNil(icon)
        let iconpath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(ServerRuntime.iconFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconpath.path))
    }
    
    func testDeleteIcon() async throws {
        let server = server
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        var icon = await runtime.icon
        XCTAssertNil(icon)
        try await runtime.updateIcon(TestData.serverIcon)
        icon = await runtime.icon
        XCTAssertNotNil(icon)
        let iconpath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(ServerRuntime.iconFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconpath.path))
        await runtime.deleteIcon()
        XCTAssertFalse(FileManager.default.fileExists(atPath: iconpath.path))
        icon = await runtime.icon
        XCTAssertNil(icon)
    }
    
    func testUpdateConfig() async throws {
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        let currentConfig = await runtime.config
        XCTAssertGreaterThan(currentConfig.count, 0)
        var gamemodeConfig = currentConfig.first {
            $0.id == "GAMEMODE"
        }!
        XCTAssertEqual(gamemodeConfig.value.description, "survival")
        
        gamemodeConfig.value = .text("creative")
        try await runtime.updateConfig([gamemodeConfig])
        let updatedConfig = await runtime.config
        XCTAssertNotEqual(currentConfig, updatedConfig)
        gamemodeConfig = updatedConfig.first {
            $0.id == "GAMEMODE"
        }!
        XCTAssertEqual(gamemodeConfig.value.description, "creative")
    }
    
    func testStartRuntime() async throws {
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        try await runtime.start()
        // wait for the runtime to start up
        try await Task.sleep(nanoseconds: 300 * 1000 * 1000)
    }
    
    func testAlreadyRunningRuntime() async throws {
        
    }
    
    func testAlreadyStoppedRuntime() async throws {
        
    }
    
    func testDeleteRunningRuntime() async throws {
        let server = server
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        try await runtime.start()
        let runtimePath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimePath.path))
        try await runtime.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimePath.path))
    }
    
    func testSendCommandToRuntime() async throws {
        
    }
    
    func testRestartRuntimeWithDelay() async throws {
        
    }
    
    func testRuntimeLogs() async throws {
        
    }
    
    func testRuntimeInfo() async throws {
        
    }
    
    func testRuntimeInfoStopped() async throws {
        
    }
}
