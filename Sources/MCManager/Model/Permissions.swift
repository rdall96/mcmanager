//
//  Permissions.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Foundation
import Fluent
import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Permissions to control user access to the API.
final class Permissions: Model, Content, @unchecked Sendable {
    static let schema = "permissions"
    
    enum FieldKeys: FieldKey {
        case isDefaults = "is_defaults"
        case application
        case users
        case servers
    }
    
    // MARK: Members
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.isDefaults.rawValue)
    internal var isDefaults: Bool
    
    @Field(key: FieldKeys.application.rawValue)
    /// Bitmask of application related permissions.
    var application: Application
    
    @Field(key: FieldKeys.users.rawValue)
    /// Bitmask of user related permissions.
    var users: Users
    
    @Field(key: FieldKeys.servers.rawValue)
    /// Bitmask of server related permissions.
    var servers: Servers
    
    // MARK: Initializers
    
    init() {}
    
    init(
        application: Application = .init(rawValue: 0),
        users: Users = .init(rawValue: 0),
        servers: Servers = .init(rawValue: 0)
    ) {
        self.id = UUID()
        self.isDefaults = false
        self.application = application
        self.users = users
        self.servers = servers
    }
    
    // MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case application = "app"
        case users
        case servers
    }
    
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            application: Application(rawValue: try container.decode(Application.RawValue.self, forKey: .application)),
            users: Users(rawValue: try container.decode(Users.RawValue.self, forKey: .users)),
            servers: Servers(rawValue: try container.decode(Servers.RawValue.self, forKey: .servers))
        )
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(application.rawValue, forKey: .application)
        try container.encode(users.rawValue, forKey: .users)
        try container.encode(servers.rawValue, forKey: .servers)
    }
}

// MARK: - Permission sets
extension Permissions {

    /// Permissions that apply to general application settings.
    struct Application: OptionSet, Codable {
        let rawValue: UInt64

        static let editSettings =   Application(rawValue: 1 << 0)
    }

    /// Permissions tthat apply to user operations.
    struct Users: OptionSet, Codable {
        let rawValue: UInt64
        
        static let readUsers =              Users(rawValue: 1 << 0)
        static let createUsers =            Users(rawValue: 1 << 1)
        static let editUsers =              Users(rawValue: 1 << 2)
        static let deleteUsers =            Users(rawValue: 1 << 3)
    }

    /// Permissions that apply to server operations.
    struct Servers: OptionSet, Codable {
        let rawValue: UInt64
        
        static let createServers =          Servers(rawValue: 1 << 0)
        static let editServers =            Servers(rawValue: 1 << 1)
        static let deleteServers =          Servers(rawValue: 1 << 2)
        
        // server properties
        static let readServerProperties =   Servers(rawValue: 1 << 3)
        static let editServerProperties =   Servers(rawValue: 1 << 4)
        
        // execution
        static let startStopServers =       Servers(rawValue: 1 << 5)
        static let readServerLogs =         Servers(rawValue: 1 << 6)
        static let sendServerCommands =     Servers(rawValue: 1 << 7)
        
        // files
        static let downloadServer =         Servers(rawValue: 1 << 8)
        static let downloadServerFiles =    Servers(rawValue: 1 << 9)
        static let uploadServerFiles =      Servers(rawValue: 1 << 10)
        static let deleteServerFiles =      Servers(rawValue: 1 << 11)

        // players
        static let manageOperators =        Servers(rawValue: 1 << 12)
        static let manageWhitelist =        Servers(rawValue: 1 << 13)
        static let manageBannedPlayers =    Servers(rawValue: 1 << 14)
    }
}
