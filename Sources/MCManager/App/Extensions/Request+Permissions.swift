//
//  Request+Permissions.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/8/24.
//

import Foundation
import Vapor

extension Request {
    
    /// Get the permissions of the user making the request
    var userPermissions: Permissions? {
        get async throws {
            let user = try auth.require(User.self)
            
            // admins can do whatever they want
            if user.isAdmin { return .all }
            
            // grab the user role and check the permissions there
            guard let roleID = user.$role.id else {
                return nil
            }
            return try await Role.find(roleID, on: db)?.permissions
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
