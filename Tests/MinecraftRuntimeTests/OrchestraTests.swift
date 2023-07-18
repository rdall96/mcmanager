//
//  OrchestraTests.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

@testable import MinecraftRuntime
import MCManager_Shared
import XCTest

final class OrchestraTests: XCTestCase {
    
    var orchestra: ServerOrchestra!
    
    override func setUp() async throws {
        orchestra = try await .init(serversRoot: FileManager.default.temporaryDirectory)
    }
    
    override func tearDown() async throws {
        // no-op
    }
    
    // MARK: - Helpers
    
    @discardableResult
    private func addServer() async throws -> Server {
        let server = TestData.createServer()
        try await orchestra.add(server: server)
        return server
    }
    
    // MARK: - Test cases
    
    func testCreateOrchestraHappyPath() async throws {
        // no-oop
    }
    
    func testAddServerHappyPath() async throws {
        try await addServer()
    }
    
    func testAddDuplicateServer() async throws {
        let server = try await addServer()
        do {
            try await orchestra.add(server: server)
            XCTFail("Expected failure when adding duplicate server")
        }
        catch {}
    }
    
    func testUpdateServerHappyPath() async throws {
        let server = try await addServer()
        server.port = 35567
        try await orchestra.update(server: server)
    }
    
    func testDeleteServerHappyPath() async throws {
        let server = try await addServer()
        try await orchestra.delete(serverWithId: server.id!)
        do {
            _ = try await orchestra.info(for: server.id!)
            XCTFail("Expected failure to get info after deleting server")
        }
        catch MCRError.invalidServerId {}
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteInvalidServer() async throws {
        do {
            _ = try await orchestra.info(for: UUID())
            XCTFail("Expected failure when deleting invalid server")
        }
        catch MCRError.invalidServerId {}
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testHasSupportedRuntimes() async throws {
        let runtimeSupport = try await orchestra.allSupportedRuntimes
        for serverType in Server.ServerType.allCases {
            XCTAssertNotNil(runtimeSupport.first(where: { $0.type == serverType }))
        }
    }
    
    func testGetInfoHappyPath() async throws {
        let server = try await addServer()
        let info = try await orchestra.info(for: server.id!)
        XCTAssertEqual(info.status, .stopped)
    }
    
    func testGetInfoForInvalidServer() async throws {
        do {
            _ = try await orchestra.info(for: UUID())
            XCTFail("Expected failure when getting info for non-existing server")
        }
        catch MCRError.invalidServerId {}
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGetConfigHappyPath() async throws {
        let server = try await addServer()
        let config = try await orchestra.config(for: server.id!)
        XCTAssertGreaterThan(config.count, 0)
    }
    
    // Other server properties tests (update config, icon, etc...) are part of the ServerRuntimeTests
}
