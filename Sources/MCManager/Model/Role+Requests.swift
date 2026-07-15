//
//  Role+Requests.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/13/26.
//

import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Request to create or edit a role.
struct RoleRequest: Content {
    /// Name of the role.
    let name: String

    /// Set of permissions granted to users with the role.
    let permissions: PermissionsRequest
}

extension Role {
    /// Update the role.
    func update(with request: RoleRequest) throws {
        // name can't be empty
        if request.name.isEmpty {
            throw RoleError.missingName
        }
        name = request.name

        // permissions: handled separately since they are their own entity

        // last updated timestamp
        updatedAt = .now
    }
}
