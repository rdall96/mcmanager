//
//  Permissions.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Foundation
import Fluent
import Vapor

final class Permissions: Model, Content {
    static let schema = "permissions"
    
    enum FieldKeys: FieldKey {
        case isDefaults = "is_defaults"
        case application
        case users
        case servers
    }
    
    // MARK: - Members
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: FieldKeys.isDefaults.rawValue)
    internal var isDefaults: Bool
    
    @Field(key: FieldKeys.application.rawValue)
    var application: Application
    
    @Field(key: FieldKeys.users.rawValue)
    var users: Users
    
    @Field(key: FieldKeys.servers.rawValue)
    var servers: Servers
    
    // MARK: - Initializers
    
    init() {}
    
    init(application: Application, users: Users, servers: Servers) {
        self.id = UUID()
        self.isDefaults = false
        self.application = application
        self.users = users
        self.servers = servers
    }
    
    // MARK: - Methods
    
    func update(with newPermissions: Permissions) {
        application = newPermissions.application
        users = newPermissions.users
        servers = newPermissions.servers
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case application = "app"
        case users
        case servers
    }
    
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            application: Application(rawValue: try container.decode(UInt64.self, forKey: .application)),
            users: Users(rawValue: try container.decode(UInt64.self, forKey: .users)),
            servers: Servers(rawValue: try container.decode(UInt64.self, forKey: .servers))
        )
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(application.rawValue, forKey: .application)
        try container.encode(users.rawValue, forKey: .users)
        try container.encode(servers.rawValue, forKey: .servers)
    }
}

// MARK: - Permissions
extension Permissions {
    
    struct Application: OptionSet, Codable {
        let rawValue: UInt64

        static let editSettings =   Application(rawValue: 1 << 0)
    }
    
    struct Users: OptionSet, Codable {
        let rawValue: UInt64
        
        static let readUsers =              Users(rawValue: 1 << 0)
        static let createUsers =            Users(rawValue: 1 << 1)
        static let editUsers =              Users(rawValue: 1 << 2)
        static let deleteUsers =            Users(rawValue: 1 << 3)
    }
    
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
    }
}
