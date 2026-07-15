//
//  Server+Requests.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/14/26.
//

import Vapor
import VaporToOpenAPI

// MARK: Create/edit

@OpenAPIDescriptable
/// Request to create or edit a Minecraft server.
struct MinecraftServerRequest: Content {

    /// Server name.
    let name: String

    /// Server type.
    /// Optional: only required for creating new servers.
    let type: MinecraftServer.ServerType?

    /// Game version.
    let version: MinecraftServer.Version

    /// Network port the server runs on.
    let port: MinecraftServer.Port

}

extension MinecraftServer {

    /// Create a Minecraft server.
    convenience init(with request: MinecraftServerRequest, settings: Settings) throws {
        // Validation checks:
        // * name can't be empty
        if request.name.isEmpty {
            throw MinecraftServerError.missingServerName
        }
        // * a type must be defined to create a new server
        guard let serverType = request.type else {
            throw MinecraftServerError.missingServerType
        }
        // * version needs to be valid
        if request.version == .none {
            throw MinecraftServerError.invalidVersion
        }
        // * port must be in allowed port range
        guard settings.allowedServerPortsData.contains(request.port) else {
            throw MinecraftServerError.invalidPort
        }

        self.init(
            name: request.name,
            type: serverType,
            version: request.version,
            port: request.port
        )
    }

    /// Update the server.
    func update(with request: MinecraftServerRequest, settings: Settings) throws {
        // name: can't be empty
        if request.name.isEmpty {
            throw MinecraftServerError.missingServerName
        }
        name = request.name

        // type: can't be changed
        if request.type != nil {
            throw MinecraftServerError.typeCantBeChanged
        }

        // version: needs to be valid
        if request.version == .none {
            throw MinecraftServerError.invalidVersion
        }
        version = request.version

        // port: must be in allowed port range
        guard settings.allowedServerPortsData.contains(request.port) else {
            throw MinecraftServerError.invalidPort
        }
        port = request.port

        // updated timestamp
        updatedAt = .now
    }
}

// MARK: - Fetch

@OpenAPIDescriptable
/// Parameters to filter servers when fetching.
struct MinecraftServerFetchRequest: Content {
    /// Server type filter.
    let type: MinecraftServer.ServerType?
}
