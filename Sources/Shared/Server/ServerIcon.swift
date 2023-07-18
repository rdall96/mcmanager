//
//  ServerIcon.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    public struct Icon {
        public let base64: String?
        
        init(base64: String?) {
            self.base64 = base64
        }
        
        public init(_ data: String) {
            self.init(base64: data)
        }
    }
}

extension Server.Icon: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(
            base64: try? container.decode(String.self)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(base64 ?? "")
    }
}

extension Server.Icon {
    @_spi(MCManager_Runtime)
    public static var none: Server.Icon {
        return .init(base64: nil)
    }
}
