//
//  Role.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Foundation
import Fluent
import Vapor

final class Role: Model, Content {
    static let schema = "roles"
    
    enum FieldKeys: FieldKey {
        case name
        case permissionsID = "permissions_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Members
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.name.rawValue)
    var name: String
    
    @Parent(key: FieldKeys.permissionsID.rawValue)
    private(set) var _permissions: Permissions
    var permissions: Permissions?
    
    @Field(key: FieldKeys.createdAt.rawValue)
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    var updatedAt: Date
    
    // MARK: - Initializers
    
    init() {}
    
    init(name: String, permissions: Permissions) throws {
        self.id = UUID()
        self.name = name
        self.$_permissions.id = try permissions.requireID()
        self.permissions = permissions
        self.createdAt = .now
        self.updatedAt = .now
    }
    
    // MARK: - Methods
    
    func update(with roleRequest: Role) {
        name = roleRequest.name
        updatedAt = .now
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case permissions
        case createdAt
        case updatedAt
    }
    
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: try container.decode(String.self, forKey: .name),
            permissions: try container.decode(Permissions.self, forKey: .permissions)
        )
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(try requireID(), forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(permissions, forKey: .permissions)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
