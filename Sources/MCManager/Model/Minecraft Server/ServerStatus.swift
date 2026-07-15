//
//  ServerStatus.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation
import Vapor
import VaporToOpenAPI

extension MinecraftServer {
    @OpenAPIDescriptable
    /// Minecraft server runtime status.
    enum Status: String, CaseIterable, Content {
        case unknown
        case stopped
        case starting
        case running
        case stopping
        case error
    }
}
