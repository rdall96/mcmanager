//
//  ServerType.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension Server {
    public enum ServerType: String, Codable {
        @_spi(MCManager_Server) case unknown
        case java
        case javaFabric = "java_fabric"
        case javaForge = "java_forge"
        case bedrock
        
        public static var allCases: [ServerType] {
            [.java, .javaFabric, .javaForge, .bedrock]
        }
    }
}
