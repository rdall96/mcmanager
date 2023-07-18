//
//  ServerVersionTests.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

@_spi(MCmanager_Tests) @testable import MCManager_Shared
import XCTest

final class ServerVersionTests: XCTestCase {
    
    private static let versions: [String] = [
         "1.12",
         "1.19.2",
         "1.9.4-forge_12.17.0.2317-1.9.4",
         "1.9-forge_12.16.1.1938-1.9.0",
         "1.10-forge_12.18.0.2000-1.10.0",
         "1.19.2-bedrock",
         "1.5.2-forge",
         "1.16.5",
         "1.17"
    ]
    
    private static let invalidVersions: [String] = [
        "latest",
        "latest-bedrock",
        "forge_12.18.0.2000-1.10.0"
    ]
    
    func testVersionDecoding() throws {
        Self.versions.forEach {
            let version = Server.Version(string: $0)
            if version == nil {
                XCTFail("Exepcted valid version from \($0)")
            }
            XCTAssertEqual(version?.description, $0)
        }
    }
    
    func testVersionDecodingInvalid() throws {
        Self.invalidVersions.forEach { version in
            if Server.Version(string: version) != nil {
                XCTFail("Exepcted invalid version from \(version)")
            }
        }
    }
}
