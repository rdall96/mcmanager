//
//  File.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 9/30/24.
//

import Foundation
import DockerSwiftAPI

extension MCServer.RuntimeSupport {
    static func tags(for serverType: MCServer.ServerType, from all: [String]) -> [String] {
        // tags contain a specific type name (except for "java")
        switch serverType {
        case .java:
            return all.lazy
                .filter { tag in
                    !tag.contains(MCServer.ServerType.javaFabric.dockerTagName) &&
                    !tag.contains(MCServer.ServerType.javaForge.dockerTagName) &&
                    !tag.contains(MCServer.ServerType.javaNeoForged.dockerTagName) &&
                    !tag.contains(MCServer.ServerType.javaQuilt.dockerTagName) &&
                    !tag.contains(MCServer.ServerType.bedrock.dockerTagName)
                }
        default:
            return all.lazy
                .filter { $0.contains(serverType.dockerTagName) }
        }
    }
}

extension MCServer.Status {
    init(with status: Docker.Container.Status) {
        switch status {
        case .created, .exited, .paused:
            self = .stopped
        case .running:
            self = .running
        case .restarting:
            self = .starting
        case .unknown:
            self = .error
        }
    }
}

extension MCServer.ServerType {
    /// The name of the Docker tag for this specific server type
    var dockerTagName: String {
        switch self {
        case .java:
            return ""
        case .javaFabric:
            return "fabric"
        case .javaForge:
            return "forge"
        case .javaNeoForged:
            return "neoForged"
        case .javaQuilt:
            return "quilt"
        case .bedrock:
            return "bedrock"
        }
    }
}
