//
//  Role.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Foundation
import Fluent
import Vapor
import VaporToOpenAPI

/// User role information.
final class Role: Model, Content, @unchecked Sendable {
    static let schema = "roles"
    
    enum FieldKeys: FieldKey {
        case name
        case permissionsID = "permissions_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: Members
    
    @ID(key: .id)
    /// Role ID.
    var id: UUID?
    
    @Field(key: FieldKeys.name.rawValue)
    /// Role name.
    var name: String

    @Parent(key: FieldKeys.permissionsID.rawValue)
    /// Set of permissions granted to users with the role.
    var permissions: Permissions
    
    @Field(key: FieldKeys.createdAt.rawValue)
    /// Date when the role was created.
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    /// Date when the role was last updated.
    var updatedAt: Date
    
    // MARK: Initializers
    
    init() {}
    
    init(name: String, permissions: Permissions) throws {
        // name can't be empty
        if name.isEmpty {
            throw RoleError.missingName
        }

        self.id = UUID()
        self.name = name
        self.$permissions.id = try permissions.requireID()
        self.createdAt = .now
        self.updatedAt = .now
    }
    
    // MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case permissions
        case createdAt
        case updatedAt
    }
}

// MARK: - Open API Spec
extension Role: OpenAPIDescriptable {
    static var openAPIDescription: (any OpenAPIDescriptionType)? {
        OpenAPIDescription<CodingKeys>("User role information.")
            .add(for: .id, "Role ID.")
            .add(for: .name, "Role name.")
            .add(for: .permissions, "Set of permissions granted to users with the role.")
            .add(for: .createdAt, "Date when the role was created in ISO 8601 format.")
            .add(for: .updatedAt, "Date when the role was last updated in ISO 8601 format.")
    }
}
