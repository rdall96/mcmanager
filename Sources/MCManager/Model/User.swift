//
//  User.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"
    
    enum FieldKeys: FieldKey {
        case username
        case password
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case adminPrivileges = "admin_privileges"
    }
    
    private enum AdminPrivileges: UInt8, Codable {
        case none = 0
        case admin
        case superAdmin
    }
    
    // MARK: - Members
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.username.rawValue)
    var username: String
    
    // this is the password has for the data model, but it's also used as a plain text password when creating new users
    @Field(key: FieldKeys.password.rawValue)
    var password: String
    
    @Field(key: FieldKeys.createdAt.rawValue)
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    var updatedAt: Date
    
    @Field(key: FieldKeys.adminPrivileges.rawValue)
    private var adminPrivileges: AdminPrivileges
    
    // MARK: - Initializers
    
    init() {}
    
    init(
        username: String,
        password: String,
        isAdmin: Bool? = nil
    ) {
        self.id = UUID()
        self.username = username
        self.password = password
        self.createdAt = .now
        self.updatedAt = .now
        self.adminPrivileges = (isAdmin ?? false) ? .admin : .none
    }
    
    var isSuperAdmin: Bool {
        adminPrivileges == .superAdmin
    }
    
    var isAdmin: Bool {
        isSuperAdmin || adminPrivileges == .admin
    }
}

// MARK: - Codable
extension User: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case password
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isAdmin = "is_admin"
    }
    
    // override decoding to set defaults so we can allow partial updates
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // we don't decode the id and the dates since those get updated internally
        self.init(
            username: try container.decodeIfPresent(String.self, forKey: .username) ?? "",
            password: try container.decodeIfPresent(String.self, forKey: .password) ?? "",
            isAdmin: try container.decodeIfPresent(Bool.self, forKey: .isAdmin)
        )
    }
    
    // override encoding since we want to omit the password field
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isAdmin, forKey: .isAdmin)
    }
}

extension User: ModelCredentialsAuthenticatable {
    static let usernameKey: KeyPath<User, Field<String>> = \User.$username
    static let passwordHashKey: KeyPath<User, Field<String>> = \User.$password
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.password)
    }
}

// MARK: Password hashing
extension User {
    /// Hash the password
    static func hashPassword(_ password: String) throws -> String {
        try Bcrypt.hash(password)
    }
}

// MARK: - Default user (admin)
extension User {
    static var superAdminUsername: String { "admin" }
    
    static func createSuperAdmin(password: String) throws -> User {
        let user = User(
            username: superAdminUsername,
            password: try hashPassword("mcmanager"),
            isAdmin: true
        )
        user.adminPrivileges = .superAdmin
        return user
    }
}
