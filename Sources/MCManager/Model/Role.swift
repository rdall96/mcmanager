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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Members
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.name.rawValue)
    var name: String
    
    @Field(key: FieldKeys.createdAt.rawValue)
    var createdAt: Date
    
    @Field(key: FieldKeys.updatedAt.rawValue)
    var updatedAt: Date
    
    // MARK: - Initializers
    
    init() {}
    
    init(name: String) {
        self.id = UUID()
        self.name = name
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
        case createdAt
        case updatedAt
    }
    
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name)
        )
    }
}
