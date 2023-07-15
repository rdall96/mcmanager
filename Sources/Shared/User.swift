//
//  User.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent

public final class User: Model {
    public static let schema = "users"
    
    // MARK: - Members
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: "username")
    public var username: String
    
    // this is the password has for the data model, but it's also used as a plain text password when creating new users
    @Field(key: "password")
    public var password: String
    
    @Field(key: "created_at")
    public var createdAt: Date
    
    @Field(key: "updated_at")
    public var updatedAt: Date
    
    @Field(key: "is_admin")
    public var isAdmin: Bool
    
    // MARK: - Initializers
    
    public init() {}
    
    public init(
        id: UUID? = UUID(),
        username: String,
        password: String,
        isAdmin: Bool = false
    ) {
        self.id = id
        self.username = username
        self.password = password
        self.createdAt = .now
        self.updatedAt = .now
        self.isAdmin = isAdmin
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
            id: nil,
            username: try container.decodeIfPresent(String.self, forKey: .username) ?? "",
            password: try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        )
    }
    
    // override encoding since we want to omit the password field
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        // Swift's Date object also adds milliseconds to the encoding, cast the time intervals to UInt to drop it
        try container.encode(UInt(createdAt.timeIntervalSince1970), forKey: .createdAt)
        try container.encode(UInt(updatedAt.timeIntervalSince1970), forKey: .updatedAt)
        try container.encode(isAdmin, forKey: .isAdmin)
    }
}
