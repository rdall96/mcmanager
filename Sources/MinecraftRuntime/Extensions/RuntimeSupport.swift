//
//  RuntimeSupport.swift
//
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

@_spi(MCManager_Server) import MCManager_Shared

extension Server.RuntimeSupport {
    static func tags(for serverType: Server.ServerType, from all: Set<String>) -> [String] {
        // tags contain a specific type name (except for "java")
        switch serverType {
        case .java:
            return all.lazy
                .filter { tag in
                    !tag.contains(Server.ServerType.javaFabric.dockerTagName) &&
                    !tag.contains(Server.ServerType.javaForge.dockerTagName) &&
                    !tag.contains(Server.ServerType.bedrock.dockerTagName)
                }
        default:
            return all.lazy
                .filter { $0.contains(serverType.dockerTagName) }
        }
    }
}
