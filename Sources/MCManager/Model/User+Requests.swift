//
//  User+Requests.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/13/26.
//

import Fluent
import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Request to create or edit a user.
struct UserRequest: Content {

    /// User name.
    let username: String

    /// User password.
    /// This field is optional for edit requests.
    /// Empty passwords are not allowed, omitted passwords are ignored.
    let password: String?

    /// Flag to determine if the user should be an admin.
    let isAdmin: Bool

    /// Role to assign to the user.
    let role: Role.IDValue?
}

extension User {
    /// Create a user.
    convenience init(with request: UserRequest) throws {
        // password is required to create a new user
        guard let password = request.password else {
            throw UserError.missingPassword
        }

        try self.init(
            username: request.username,
            password: password,
            isAdmin: request.isAdmin,
            roleID: request.role
        )
    }

    /// Update the user.
    func update(with request: UserRequest) throws {
        // username
        if request.username.isEmpty {
            throw UserError.missingUsername
        }
        username = request.username

        // password
        if let password = request.password {
            guard !password.isEmpty else {
                throw UserError.missingPassword
            }
            try updatePassword(password)
        }

        // role: admins don't have a role, ignore any attempts to change it
        if !isAdmin {
            $role.id = request.role
        }

        // admin privileges: can never be changed for the super admin account
        if !isSuperAdmin {
            if request.isAdmin {
                grantAdmin()
            }
            else {
                revokeAdmin()
            }
        }

        // last updated timestamp
        updatedAt = .now
    }
}
