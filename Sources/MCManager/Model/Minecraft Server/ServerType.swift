//
//  ServerType.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor
import VaporToOpenAPI

extension MinecraftServer {
    @OpenAPIDescriptable
    /// Minecraft server type.
    enum ServerType: String, CaseIterable, Content {
        case java
        case javaFabric = "java_fabric"
        case javaForge = "java_forge"
        case javaNeoForged = "java_neo_forged"
        case javaQuilt = "java_quilt"
        case bedrock
    }
}
