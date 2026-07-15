//
//  RuntimeSupport.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor
import VaporToOpenAPI

extension MinecraftServer {
    @OpenAPIDescriptable
    /// Data regarding the types and game versions that can be used to create a server.
    /// This should be used a reference before calling `createServer`.
    struct RuntimeSupport: Content {

        /// Type of supported Minecraft server.
        let type: ServerType
        /// List of available Minecraft game versions, sorted newest first.
        let versions: [Version]
        
        init(type: ServerType, versions: [Version]) {
            self.type = type
            self.versions = versions
        }
        
        init(type: ServerType, versions: [String]) {
            let versions = versions
                .compactMap { Version(string: $0) }
                .sorted(by: >)
            self.init(type: type, versions: versions)
        }

        // MARK: Codable

        enum CodingKeys: String, CodingKey {
            case type
            case versions
        }
    }
}
