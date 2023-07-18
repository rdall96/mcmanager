//
//  RuntimeTests.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

@testable import MinecraftRuntime
@_spi(MCManager_Tests) import MCManager_Shared
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
    
    // MARK: - Test cases
    
    func testCreateHappyPath() async throws {
        let server = TestData.createServer()
        let serverPath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertFalse(FileManager.default.fileExists(atPath: serverPath.path))
        _ = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        XCTAssertTrue(FileManager.default.fileExists(atPath: serverPath.path))
    }
    
    func testNewRuntimeHasDefaultConfig() async throws {
        let server = TestData.createServer()
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
    
    func testUpdateRuntimeHappyPath() async throws {
        let server = TestData.createServer()
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        server.port = ServerRuntime.minecraftServerPort
        server.version = TestData.versions.randomElement()!
        try await runtime.update(server)
    }
    
    func testUpdateRuntimeInvalid() async throws {
        let server = TestData.createServer()
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
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
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        let runtimePath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimePath.path))
        try await runtime.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimePath.path))
    }
    
    func testUpdateIconHappyPath() async throws {
        let server = TestData.createServer()
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        var icon = await runtime.icon
        XCTAssertNil(icon.base64)
        try await runtime.updateIcon(TestData.serverIcon)
        icon = await runtime.icon
        XCTAssertNotNil(icon)
        let iconpath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(ServerRuntime.iconFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconpath.path))
    }
    
    func testUpdateIconWithInvalidData() async throws {
        let server = TestData.createServer()
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        do {
            try await runtime.updateIcon(.init("definitely_not_base64"))
            XCTFail("Expected failure when updating icon with invalid data")
        }
        catch MCRError.invalidIconData {}
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteIcon() async throws {
        let server = TestData.createServer()
        let runtime = try await ServerRuntime(info: server, rootPath: testPath, docker: docker)
        var icon = await runtime.icon
        XCTAssertNil(icon.base64)
        try await runtime.updateIcon(TestData.serverIcon)
        icon = await runtime.icon
        XCTAssertNotNil(icon)
        let iconpath = testPath
            .appendingPathComponent(server.id!.pathSafeString)
            .appendingPathComponent(ServerRuntime.iconFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconpath.path))
        await runtime.removeIcon()
        XCTAssertFalse(FileManager.default.fileExists(atPath: iconpath.path))
        icon = await runtime.icon
        XCTAssertNil(icon.base64)
    }
    
    func testUpdateConfigHappyPath() async throws {
        let runtime = try await ServerRuntime(info: TestData.createServer(), rootPath: testPath, docker: docker)
        var config = await runtime.config
        XCTAssert(
            config.first(where: { $0.id == "PVP" })?.value.description == "true"
        )
        try await runtime.updateConfig(
            [.init(id: "PVP", value: .flag(false))]
        )
        config = await runtime.config
        XCTAssert(
            config.first(where: { $0.id == "PVP" })?.value.description == "false"
        )
    }
    
    func testUpdateConfigWithUnknownKey() async throws {
        let runtime = try await ServerRuntime(info: TestData.createServer(), rootPath: testPath, docker: docker)
        do {
            try await runtime.updateConfig(
                [.init(id: "INVICIBLE", value: .flag(true))]
            )
            XCTFail("Expected failure when updating server config with unknwown key")
        }
        catch MCRError.invalidServerConfigKey("INVICIBLE") {}
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
        let runtime = try await ServerRuntime(info: TestData.createServer(), rootPath: testPath, docker: docker)
        let info = await runtime.info
        XCTAssertEqual(info.status, .stopped)
        XCTAssertEqual(info.onlinePlayerCount, 0)
        XCTAssertEqual(info.cpuUsage, 0)
        XCTAssertEqual(info.memoryUsageBytes, 0)
    }
    
    func testRuntimeInfoStopped() async throws {
        _ = XCTSkip("Not implemented")
    }
}
