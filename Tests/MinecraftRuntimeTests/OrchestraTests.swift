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
    
    // MARK: - Test cases
    
    func testHasSupportedRuntimes() async throws {
        let runtimeSupport = try await orchestra.allSupportedRuntimes
        for serverType in Server.ServerType.allCases {
            XCTAssertNotNil(runtimeSupport.first(where: { $0.type == serverType }))
        }
    }
}
