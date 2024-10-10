//
//  Permissions.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/7/24.
//

import Foundation
import Fluent

struct Permissions: Codable {
    let application: Application
    let users: Users
    let servers: Servers
    
    struct Application: OptionSet, Codable {
        let rawValue: UInt64
        
        static let readSettings =   Application(rawValue: 1 << 0)
        static let writeSettings =  Application(rawValue: 1 << 1)
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
        static let writeServerProperties =  Servers(rawValue: 1 << 4)
        
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
    
    static let defaults = Permissions(
        application: .readSettings,
        users: .readUsers,
        servers: Servers(rawValue: .max)
    )
    
    static let all = Permissions(
        application: .init(rawValue: .max),
        users: .init(rawValue: .max),
        servers: .init(rawValue: .max)
    )
}

//struct PermissionResponse {
//    
//    struct Application: Codable {
//        
//        let readSettings: Bool
//        let writeSettings: Bool
//        
//        static let defaults = Application(
//            readSettings: true,
//            writeSettings: false
//        )
//    }
//    
//    struct Users: Codable {
//        
//        let readUsers: Bool
//        let createUsers: Bool
//        let editUsers: Bool
//        let deleteUsers: Bool
//        
//        let manageUserPermissions: Bool
//        
//        static let defaults = Users(
//            readUsers: true,
//            createUsers: false,
//            editUsers: false,
//            deleteUsers: false,
//            manageUserPermissions: false
//        )
//    }
//    
//    
//    struct Servers: Codable {
//        
//        let createServers: Bool
//        let editServers: Bool
//        let deleteServers: Bool
//        
//        // server properties
//        let readServerProperties: Bool
//        let writeServerProperties: Bool
//        
//        // execution
//        let startStopServers: Bool
//        let readServerLogs: Bool
//        let sendServerCommands: Bool
//        
//        // files
//        let downloadServer: Bool
//        let downloadServerFiles: Bool
//        let uploadServerFiles: Bool
//        let deleteServerFiles: Bool
//        
//        static let defaults = Servers(
//            createServers: true,
//            editServers: true,
//            deleteServers: true,
//            readServerProperties: true,
//            writeServerProperties: true,
//            startStopServers: true,
//            readServerLogs: true,
//            sendServerCommands: true,
//            downloadServer: true,
//            downloadServerFiles: true,
//            uploadServerFiles: true,
//            deleteServerFiles: true
//        )
//    }
//}
