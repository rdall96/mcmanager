//
//  Request+Permissions.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/8/24.
//

import Foundation
import Vapor
import FluentKit

extension Permissions {
    
    private convenience init(
        isDefaults: Bool = false,
        application: Application,
        users: Users,
        servers: Servers
    ) {
        self.init(application: application, users: users, servers: servers)
        self.isDefaults = isDefaults
    }

    /// Hard-coded default permissions.
    ///
    /// - NOTE: Only use this during first time setup to write the defaults to the database.
    ///         Any futher action on the default permissions should go through the proper route which interacts with the database instance.
    static var defaults = Permissions(
        isDefaults: true,
        application: .readSettings,
        users: .readUsers,
        servers: [
            .createServers, .editServers, .deleteServers,
            .readServerProperties, .editServerProperties,
            .startStopServers, .readServerLogs,
            .downloadServerFiles, .uploadServerFiles, .deleteServerFiles
        ]
    )

    /// Read the default permissions from the given database.
    static func defaults(on db: Database) async throws -> Permissions? {
        try await Permissions.query(on: db)
            .filter(\Permissions.$isDefaults, .equal, true)
            .first()
    }

    fileprivate static var all = Permissions(
        application: .init(rawValue: .max),
        users: .init(rawValue: .max),
        servers: .init(rawValue: .max)
    )
}

extension Request {
    
    /// Get the permissions of the user making the request
    var userPermissions: Permissions? {
        get async throws {
            let user = try auth.require(User.self)
            
            // admins can do whatever they want
            if user.isAdmin { return .all }
            
            // grab the user role and check the permissions there
            // users without an assigned role, get default permissions
            let defaultPermissions = try await Permissions.defaults(on: db)
            guard let roleID = user.$role.id else {
                return defaultPermissions
            }
            return try await Role.find(roleID, on: db)?.permissions ?? defaultPermissions
        }
    }
    
    func userHasPermissions(for action: Permissions.Application) async throws -> Bool {
        try await userPermissions?.application.contains(action) ?? false
    }
    
    func userHasPermissions(for action: Permissions.Users) async throws -> Bool {
        try await userPermissions?.users.contains(action) ?? false
    }
    
    func userHasPermissions(for action: Permissions.Servers) async throws -> Bool {
        try await userPermissions?.servers.contains(action) ?? false
    }
}
