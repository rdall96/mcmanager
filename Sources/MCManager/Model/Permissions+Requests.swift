//
//  Permissions+Requests.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/13/26.
//

import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Request to create or edit permissions.
struct PermissionsRequest: Content {
    /// Bitmask of application related permissions.
    let appPermissions: Permissions.Application
    /// Bitmask of user related permissions.
    let userPermissions: Permissions.Users
    /// Bitmask of server related permissions.
    let serverPermissions: Permissions.Servers

    init(
        application: Permissions.Application = .init(rawValue: 0),
        users: Permissions.Users = .init(rawValue: 0),
        servers: Permissions.Servers = .init(rawValue: 0)
    ) {
        self.appPermissions = application
        self.userPermissions = users
        self.serverPermissions = servers
    }

    init(with permissions: Permissions) {
        self.init(
            application: permissions.application,
            users: permissions.users,
            servers: permissions.servers
        )
    }

    init(with request: RoleRequest) {
        self.init(
            application: request.permissions.appPermissions,
            users: request.permissions.userPermissions,
            servers: request.permissions.serverPermissions
        )
    }

    enum CodingKeys: String, CodingKey {
        case appPermissions = "app"
        case userPermissions = "users"
        case serverPermissions = "servers"
    }
}

extension Permissions {
    /// Create permissions.
    convenience init(with request: PermissionsRequest) {
        self.init(
            application: request.appPermissions,
            users: request.userPermissions,
            servers: request.serverPermissions
        )
    }

    /// Create permissions.
    convenience init(with request: RoleRequest) {
        self.init(
            application: request.permissions.appPermissions,
            users: request.permissions.userPermissions,
            servers: request.permissions.serverPermissions
        )
    }

    /// Update permissions.
    func update(with request: PermissionsRequest) {
        application = request.appPermissions
        users = request.userPermissions
        servers = request.serverPermissions
    }

    /// Update permissions.
    func update(with request: RoleRequest) {
        application = request.permissions.appPermissions
        users = request.permissions.userPermissions
        servers = request.permissions.serverPermissions
    }
}
