//
//  RoutesBuilder+Extensions.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 9/30/24.
//

import Foundation
import Vapor

extension RoutesBuilder {
    
    /// This route requires the user to provide their credentials
    func requireUserCredentials() -> any RoutesBuilder {
        return self
            .grouped(User.asyncCredentialsAuthenticator())
            .grouped(User.guardMiddleware(throwing: AuthenticationError.invalidCredentials))
    }
    
    /// This route requires the user to be authenticated
    func requireAuthentication() -> any RoutesBuilder {
        return self
            .grouped(SessionToken.Authenticator())
            .grouped(User.guardMiddleware(throwing: AuthenticationError.notAuthenticated))
    }
    
    /// Group routes by the API version
    func apiVersion(_ version: APIVersion) -> any RoutesBuilder {
        return self.grouped("\(version.rawValue)")
    }
}
