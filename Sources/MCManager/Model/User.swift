//
//  User.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import VaporToOpenAPI

/// User information.
final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    enum FieldKeys: FieldKey {
        case username
        case password
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case adminPrivileges = "admin_privileges"
        case roleID = "role_id"
    }
    
    private enum AdminPrivileges: UInt8, Codable {
        case none = 0
        case admin
        case superAdmin
    }
    
    // MARK: Members

    @ID(key: .id)
    /// User ID.
    var id: UUID?
    
    @Field(key: FieldKeys.username.rawValue)
    /// User name.
    var username: String
    
    @Field(key: FieldKeys.password.rawValue)
    /// User password. Only present when creating a new user.
    /// - NOTE: This is the password hash for the data model, but it's also used as a plain text password when creating new users.
    var password: String
    
    @Field(key: FieldKeys.createdAt.rawValue)
    /// Date when the user was created.
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    /// Date when the user was last updated.
    var updatedAt: Date
    
    @Field(key: FieldKeys.adminPrivileges.rawValue)
    private var adminPrivileges: AdminPrivileges
    
    @OptionalParent(key: FieldKeys.roleID.rawValue)
    /// Role this user is assigned to.
    /// Determines the user's permissions.
    var role: Role?
    
    // MARK: Initializers
    
    init() {}
    
    init(
        username: String,
        password: String,
        isAdmin: Bool = false,
        roleID: UUID? = nil
    ) throws {
        if username.isEmpty {
            throw UserError.missingUsername
        }

        self.id = UUID()
        self.username = username
        self.password = try User.hashPassword(password)
        self.createdAt = .now
        self.updatedAt = .now
        self.adminPrivileges = isAdmin ? .admin : .none
        
        // some fields don't matter for admins
        if !isAdmin {
            self.$role.id = roleID
        }
    }
    
    // MARK: Methods
    
    var isSuperAdmin: Bool {
        adminPrivileges == .superAdmin
    }
    
    var isAdmin: Bool {
        isSuperAdmin || adminPrivileges == .admin
    }

    /// Grant a user admin privileges.
    func grantAdmin() {
        adminPrivileges = .admin
    }

    /// Revoke a user's admin privileges.
    func revokeAdmin() {
        adminPrivileges = .none
    }
    
    // MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case password
        case createdAt
        case updatedAt
        case isAdmin
        case role
    }
    
    // override encoding:
    // * omit the password
    // * translate the admin privileges into a simple flag
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(try requireID(), forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isAdmin, forKey: .isAdmin)
        try container.encode($role.id, forKey: .role)
    }
}

// MARK: - Authentication
extension User: ModelCredentialsAuthenticatable {
    static let usernameKey: KeyPath<User, Field<String>> = \User.$username
    static let passwordHashKey: KeyPath<User, Field<String>> = \User.$password
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

// MARK: - Password hashing
extension User {
    /// Hash the password
    fileprivate static func hashPassword(_ password: String) throws -> String {
        if password.isEmpty {
            throw UserError.missingPassword
        }
        return try Bcrypt.hash(password)
    }

    /// Update the user's password.
    func updatePassword(_ newPassword: String) throws {
        password = try Self.hashPassword(newPassword)
    }
}

// MARK: - Default user (admin)
extension User {
    static var superAdminUsername: String { "admin" }
    
    static func createSuperAdmin(password: String) throws -> User {
        let user = try User(
            username: superAdminUsername,
            password: "mcmanager",
            isAdmin: true
        )
        user.adminPrivileges = .superAdmin
        return user
    }
}

// MARK: - Open API Spec
extension User: OpenAPIDescriptable {
    static var openAPIDescription: OpenAPIDescriptionType? {
        OpenAPIDescription<CodingKeys>("User information.")
            .add(for: .id, "User ID.")
            .add(for: .username, "User name.")
            .add(for: .password, "User password. Only present when creating a new user.")
            .add(for: .createdAt, "Date when the user was created in ISO 8601 format.")
            .add(for: .updatedAt, "Date when the user was last updated in ISO 8601 format.")
            .add(for: .isAdmin, "Flag indicating if the user is an admin.")
            .add(for: .role, "Role ID of the user.")
    }
}
