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
        case roleID = "role_id"
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
    
    @OptionalParent(key: FieldKeys.roleID.rawValue)
    var role: Role?
    
    // MARK: - Initializers
    
    init() {}
    
    init(
        username: String,
        password: String,
        isAdmin: Bool? = nil,
        roleID: UUID? = nil
    ) throws {
        self.id = UUID()
        self.username = username
        self.password = try User.hashPassword(password)
        self.createdAt = .now
        self.updatedAt = .now
        self.adminPrivileges = (isAdmin ?? false) ? .admin : .none
        
        // some fields don't matter for admins
        if let isAdmin, !isAdmin {
            self.$role.id = roleID
        }
    }
    
    // MARK: - Methods
    
    var isSuperAdmin: Bool {
        adminPrivileges == .superAdmin
    }
    
    var isAdmin: Bool {
        isSuperAdmin || adminPrivileges == .admin
    }
    
    func update(with request: User) throws {
        if !request.username.isEmpty {
            username = request.username
        }
        if !request.password.isEmpty {
            password = try User.hashPassword(request.password)
        }
        
        // some fields can't be updated for the admins
        if !isAdmin {
            $role.id = request.$role.id
        }
        
        updatedAt = .now
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case password
        case createdAt
        case updatedAt
        case isAdmin
        case role
    }
    
    // override decoding to set defaults so we can allow partial updates
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        
        // we don't decode the id and the dates since those get updated internally
        id = nil
        createdAt = .now
        updatedAt = .now
        
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        
        let isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin)
        adminPrivileges = (isAdmin ?? false) ? .admin : .none
        
        $role.id = try container.decodeIfPresent(UUID.self, forKey: .role)
    }
    
    // override encoding since we want to omit the password field
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
    fileprivate static func hashPassword(_ password: String) throws -> String {
        try Bcrypt.hash(password)
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
