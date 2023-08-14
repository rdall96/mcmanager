//
//  User.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Foundation
import Fluent

public final class User: Model {
    @_spi(MCManager_Server)
    public static let schema = "users"

    @_spi(MCManager_Server)
    public enum FieldKeys: FieldKey {
        case username
        case password
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isAdmin = "is_admin"
    }
    
    // MARK: - Members
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: FieldKeys.username.rawValue)
    public var username: String
    
    // this is the password has for the data model, but it's also used as a plain text password when creating new users
    @Field(key: FieldKeys.password.rawValue)
    public var password: String
    
    @Field(key: FieldKeys.createdAt.rawValue)
    public var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    public var updatedAt: Date
    
    @Field(key: FieldKeys.isAdmin.rawValue)
    public var isAdmin: Bool
    
    // MARK: - Initializers
    
    public init() {}
    
    @_spi(MCManager_Server)
    public init(
        id: UUID,
        username: String,
        password: String,
        isAdmin: Bool
    ) {
        self.id = id
        self.username = username
        self.password = password
        self.createdAt = .now
        self.updatedAt = .now
        self.isAdmin = isAdmin
    }
    
    public convenience init(username: String, password: String) {
        self.init(
            id: UUID(),
            username: username,
            password: password,
            isAdmin: false
        )
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
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // we don't decode the id and the dates since those get updated internally
        self.init(
            username: try container.decodeIfPresent(String.self, forKey: .username) ?? "",
            password: try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        )
    }
    
    // override encoding since we want to omit the password field
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isAdmin, forKey: .isAdmin)
    }
}
