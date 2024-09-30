//
//  ServerIcon.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor

extension MCServer {
    struct Icon: Content {
        let base64: String
        
        init(base64: String) {
            self.base64 = base64
        }
        
        init?(atPath url: URL) {
            guard FileManager.default.fileExists(atPath: url.path),
                  let contents = try? Data(contentsOf: url)
            else {
                return nil
            }
            self.base64 = contents.base64EncodedString()
        }
    }
}

extension MCServer.Icon: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(base64: try container.decode(String.self))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(base64)
    }
}
