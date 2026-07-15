//
//  RuntimeTests.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

@testable import MCManager
import DockerSwiftAPI
import XCTest

final class RuntimeTests: XCTestCase {
    
    var testPath: URL!
    
    override func setUp() {
        // assign a temporary directory
        testPath = FileManager.default.temporaryDirectory
    }
    
    private func createRuntime(with server: MinecraftServer) async throws -> MinecraftServerRuntime {
        try await MinecraftServerRuntime(info: server, rootPath: testPath)
    }
    
    // MARK: - Test cases
    
    func testCreateHappyPath() async throws {
        let server = TestData.createServer()
        let serverPath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertFalse(FileManager.default.fileExists(atPath: serverPath.path))
        _ = try await createRuntime(with: server)
        XCTAssertTrue(FileManager.default.fileExists(atPath: serverPath.path))
    }
    
    func testNewRuntimeHasDefaultConfig() async throws {
        let server = TestData.createServer()
        let configPath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(MinecraftServerRuntime.Defaults.configFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configPath.path))
        _ = try await createRuntime(with: server)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
        let data = try Data(contentsOf: configPath)
        let config: [MinecraftServer.Config] = try JSONDecoder().decode([MinecraftServer.Config].self, from: data)
        XCTAssertGreaterThan(config.count, 0)
        XCTAssertNotNil(config.first(where: { $0.id == "GAMEMODE" }))
    }
    
    func testUpdateRuntimeHappyPath() async throws {
        let server = TestData.createServer()
        let runtime = try await createRuntime(with: server)
        server.port = MinecraftServerRuntime.Defaults.minecraftServerPort
        server.version = TestData.versions.randomElement()!
        try await runtime.update(server)
    }
    
    func testUpdateRuntimeInvalid() async throws {
        let server = TestData.createServer()
        let runtime = try await createRuntime(with: server)
        server.id = UUID()
        server.version = TestData.versions.randomElement()!
        do {
            try await runtime.update(server)
            XCTFail()
        }
        catch {}
    }
    
    func testDeleteRuntimeHappyPath() async throws {
        let server = TestData.createServer()
        let runtime = try await createRuntime(with: server)
        let runtimePath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimePath.path))
        try await runtime.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimePath.path))
    }
    
    func testUpdateIconHappyPath() async throws {
        let server = TestData.createServer()
        let runtime = try await createRuntime(with: server)
        var icon = await runtime.icon
        XCTAssertNil(icon.base64)
        try await runtime.updateIcon(TestData.serverIcon)
        icon = await runtime.icon
        XCTAssertNotNil(icon)
        let iconpath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(MinecraftServerRuntime.Defaults.iconFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconpath.path))
    }
    
    func testUpdateIconWithInvalidData() async throws {
        let server = TestData.createServer()
        let runtime = try await createRuntime(with: server)
        do {
            try await runtime.updateIcon(MinecraftServer.Icon(base64: "definitely_not_base64"))
            XCTFail("Expected failure when updating icon with invalid data")
        }
        catch MinecraftServerError.invalidIconData {}
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteIcon() async throws {
        let server = TestData.createServer()
        let runtime = try await createRuntime(with: server)
        var icon = await runtime.icon
        XCTAssertNil(icon.base64)
        try await runtime.updateIcon(TestData.serverIcon)
        icon = await runtime.icon
        XCTAssertNotNil(icon)
        let iconpath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(MinecraftServerRuntime.Defaults.iconFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconpath.path))
        await runtime.removeIcon()
        XCTAssertFalse(FileManager.default.fileExists(atPath: iconpath.path))
        icon = await runtime.icon
        XCTAssertNil(icon.base64)
    }
    
    func testUpdateConfigHappyPath() async throws {
        let runtime = try await createRuntime(with: TestData.createServer())
        var config = await runtime.config
        XCTAssert(
            config.first(where: { $0.id == "PVP" })?.value.description == "true"
        )
        try await runtime.updateConfig(
            [MinecraftServer.Config("PVP", value: .flag(false))]
        )
        config = await runtime.config
        XCTAssert(
            config.first(where: { $0.id == "PVP" })?.value.description == "false"
        )
    }
    
    func testUpdateConfigWithUnknownKey() async throws {
        let runtime = try await createRuntime(with: TestData.createServer())
        do {
            try await runtime.updateConfig(
                [MinecraftServer.Config("INVICIBLE", value: .flag(true))]
            )
            XCTFail("Expected failure when updating server config with unknwown key")
        }
        catch MinecraftServerError.invalidServerProperty("INVICIBLE") {}
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testStartRuntimeHappyPath() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testStartAlreadyRunningRuntime() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testStopAlreadyStoppedRuntime() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testDeleteRunningRuntime() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testSendCommandToRuntime() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testRestartRuntimeWithDelay() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testRuntimeLogs() async throws {
        _ = XCTSkip("Not implemented")
    }
    
    func testRuntimeInfo() async throws {
        let runtime = try await createRuntime(with: TestData.createServer())
        let info = try await runtime.info
        XCTAssertEqual(info.status, .stopped)
        XCTAssertEqual(info.onlinePlayers, [])
        XCTAssertEqual(info.maximumPlayerCount, 0)
    }
    
    func testRuntimeMetrics() async throws {
        let runtime = try await createRuntime(with: TestData.createServer())
        let metrics = try await runtime.metrics
        XCTAssertEqual(metrics.needsRestart, true)
        XCTAssertEqual(metrics.cpuPercent, 0)
        XCTAssertEqual(metrics.memoryUsageBytes, 0)
    }
    
    func testRuntimeInfoStopped() async throws {
        _ = XCTSkip("Not implemented")
    }
}

// MARK: - Test extensions
extension MinecraftServerRuntime {
    var getProcess: Docker.Container { process }
}
