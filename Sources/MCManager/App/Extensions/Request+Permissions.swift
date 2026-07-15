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
    static var defaults: Permissions {
        Permissions(
            isDefaults: true,
            application: [],
            users: .readUsers,
            servers: [
                .createServers, .editServers, .deleteServers,
                .readServerProperties, .editServerProperties,
                .startStopServers, .readServerLogs,
                .downloadServerFiles, .uploadServerFiles, .deleteServerFiles,
                .manageWhitelist
            ]
        )
    }

    /// Read the default permissions from the given database.
    static func defaults(on db: Database) async throws -> Permissions? {
        try await Permissions.query(on: db)
            .filter(\Permissions.$isDefaults, .equal, true)
            .first()
    }

    fileprivate static var all: Permissions {
        Permissions(
            application: .init(rawValue: .max),
            users: .init(rawValue: .max),
            servers: .init(rawValue: .max)
        )
    }
}

extension Request {
    
    /// Get the permissions of the user making the request
    var userPermissions: Permissions {
        get async throws {
            let user: User
            do {
                user = try auth.require(User.self)
            }
            catch {
                throw AuthenticationError.notAuthenticated
            }

            // admins can do whatever they want
            if user.isAdmin { return .all }

            // Load the default permissions for later user
            let defaultPermissions: Permissions
            do {
                defaultPermissions = try await Permissions.defaults(on: db) ?? .defaults
            }
            catch {
                throw UserError.unknown
            }

            // Grab the user's role to extract the permissions
            guard let roleID = user.$role.id, let role = try await Role.find(roleID, on: db) else {
                // user has no role, use default permissions
                return defaultPermissions
            }
            guard let permissions = try await Permissions.find(role.$permissions.id, on: db) else {
                // role has no permissions linked with it (error: invalid role, DB corrupted or out of sync)
                throw RoleError.missingPermissions
            }
            return permissions
        }
    }
    
    func userHasPermissions(for action: Permissions.Application) async throws -> Bool {
        try await userPermissions.application.contains(action)
    }
    
    func userHasPermissions(for action: Permissions.Users) async throws -> Bool {
        try await userPermissions.users.contains(action)
    }
    
    func userHasPermissions(for action: Permissions.Servers) async throws -> Bool {
        try await userPermissions.servers.contains(action)
    }
}
