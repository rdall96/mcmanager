//
//  ServerType.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import MCManager_Shared

extension Server.ServerType {
    /// The name of the Docker tag for this specific server type
    var dockerTagName: String {
        switch self {
        case .java:
            return ""
        case .javaFabric:
            return "fabric"
        case .javaForge:
            return "forge"
        case .bedrock:
            return "bedrock"
        }
    }
}
