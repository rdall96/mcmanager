//
//  RuntimeSupport.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor

extension MCServer {
    /**
     Data regarding the types and game versions that can be used to create a server.
     This should be used a reference before calling `createServer`.
     */
    struct RuntimeSupport: Codable, Content {
        let type: ServerType
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
    }
}
