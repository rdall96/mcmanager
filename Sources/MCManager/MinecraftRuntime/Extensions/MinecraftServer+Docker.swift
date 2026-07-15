//
//  MinecraftServer+Docker.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 9/30/24.
//

import Foundation
import DockerSwiftAPI

extension MinecraftServer.RuntimeSupport {
    static func tags(for serverType: MinecraftServer.ServerType, from all: [String]) -> [String] {
        // tags contain a specific type name (except for "java")
        switch serverType {
        case .java:
            return all.lazy
                .filter { tag in
                    !tag.contains(MinecraftServer.ServerType.javaFabric.dockerTagName) &&
                    !tag.contains(MinecraftServer.ServerType.javaForge.dockerTagName) &&
                    !tag.contains(MinecraftServer.ServerType.javaNeoForged.dockerTagName) &&
                    !tag.contains(MinecraftServer.ServerType.javaQuilt.dockerTagName) &&
                    !tag.contains(MinecraftServer.ServerType.bedrock.dockerTagName)
                }
        default:
            return all.lazy
                .filter { $0.contains(serverType.dockerTagName) }
        }
    }
}

extension MinecraftServer.Status {
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

extension MinecraftServer.ServerType {
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
