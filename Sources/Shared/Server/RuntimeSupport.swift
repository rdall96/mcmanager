//
//  RuntimeSupport.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    /**
     Data regarding the types and game versions that can be used to create a server.
     This should be used a reference before calling `createServer`.
     */
    public struct RuntimeSupport: Codable {
        public let type: ServerType
        public let versions: [Server.Version]
        
        @_spi(MCManager_Runtime)
        public init(
            type: Server.ServerType,
            versions: [String]
        ) {
            self.type = type
            self.versions = versions.compactMap {
                Server.Version(string: $0)
            }
            .sorted(by: >)
        }
    }
}
