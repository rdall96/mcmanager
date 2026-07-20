//
//  Role+Responses.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/13/26.
//

import Fluent
import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// User role information.
struct RoleResponse: Content {
    /// Role ID.
    let id: UUID
    /// Name of the role.
    let name: String
    /// Set of permissions granted to users with the role.
    let permissions: Permissions

    init(id: UUID = UUID(), name: String, permissions: Permissions) {
        self.id = id
        self.name = name
        self.permissions = permissions
    }

    init(role: Role, permissions: Permissions) throws {
        self.init(
            id: try role.requireID(),
            name: role.name,
            permissions: permissions
        )
    }
}
