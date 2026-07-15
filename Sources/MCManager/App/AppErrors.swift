//
//  AppErrors.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 11/13/25.
//

import Foundation
import Vapor

// MARK: - Error protocol

protocol ApplicationError: AbortError, LocalizedError {
    typealias ErrorCode = UInt

    var code: ErrorCode { get }

    var description: String { get }
}

extension ApplicationError {
    var errorDescription: String? { description }
    var failureReason: String? { reason }
}

// MARK: - MCManager errors

enum AuthenticationError: ApplicationError {
    case notAuthenticated
    case invalidCredentials

    var description: String {
        switch self {
        case .notAuthenticated: "Not authenticated."
        case .invalidCredentials: "Invalid credentials."
        }
    }

    var reason: String {
        switch self {
        case .notAuthenticated: "You are not logged in."
        case .invalidCredentials: "The provided credentials are invalid."
        }
    }

    var status: HTTPResponseStatus {
        switch self {
        case .notAuthenticated: .unauthorized
        case .invalidCredentials: .badRequest
        }
    }

    var code: ErrorCode {
        switch self {
        case .notAuthenticated: 1001
        case .invalidCredentials: 1002
        }
    }
}

enum UserError: ApplicationError {
    case unknown
    case notFound
    case unauthorized
    case alreadyExists
    case missingID
    case invalidID
    case missingUsername
    case missingPassword
    case adminRequired
    case invalidRole
    case cantDeleteAdmin

    var description: String {
        switch self {
        case .unknown: "Unknown user error."
        case .notFound: "User not found."
        case .unauthorized: "Unauthorized."
        case .alreadyExists: "User already exists."
        case .missingID: "Missing user ID."
        case .invalidID: "Invalid user ID."
        case .missingUsername: "Missing username."
        case .missingPassword: "Missing password."
        case .adminRequired: "Admin required."
        case .invalidRole: "Invalid user role."
        case .cantDeleteAdmin: "Cannot delete admin user."
        }
    }

    var reason: String {
        switch self {
        case .unknown: "An unknown error occurred."
        case .unauthorized: "You do not have the necessary permissions to perform this action."
        case .alreadyExists: "A user with that username already exists."
        case .missingPassword: "A user password is required."
        case .adminRequired: "Only administrators can perform this action."
        case .cantDeleteAdmin: "You cannot delete the admin user."
        default: description
        }
    }

    var status: HTTPStatus {
        switch self {
        case .unknown: .internalServerError
        case .notFound: .notFound
        case .unauthorized: .unauthorized
        case .alreadyExists: .conflict
        case .missingID, .invalidID: .badRequest
        case .missingUsername, .missingPassword, .invalidRole: .badRequest
        case .adminRequired, .cantDeleteAdmin: .forbidden
        }
    }

    var code: ErrorCode {
        switch self {
        case .unknown: 2000
        case .notFound: 2001
        case .unauthorized: 2002
        case .alreadyExists: 2003
        case .missingID: 2004
        case .invalidID: 2005
        case .missingUsername: 2006
        case .missingPassword: 2007
        case .adminRequired: 2008
        case .invalidRole: 2009
        case .cantDeleteAdmin: 2010
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingID: "Please provide a user ID and try again."
        case .invalidID: "Check that the user ID is valid and try again."
        case .adminRequired: "Sign in with an admin account and try again."
        default: nil
        }
    }
}

enum RoleError: ApplicationError, LocalizedError {
    case notFound
    case missingID
    case invalidID(String)
    case missingName
    case missingPermissions
    case alreadyExists
    case cantDelete

    var description: String {
        switch self {
        case .notFound: "Role not found."
        case .missingID: "Missing role ID."
        case .invalidID(_): "Invalid role ID."
        case .missingName: "Missing role name."
        case .missingPermissions: "Role permissions not found."
        case .alreadyExists: "Role already exists."
        case .cantDelete: "Role can't be deleted."
        }
    }

    var reason: String {
        switch self {
        case .invalidID(let string): "Invalid role ID: \(string)."
        case .alreadyExists: "A role with that name already exists."
        default: description
        }
    }

    var status: HTTPResponseStatus {
        switch self {
        case .notFound: .notFound
        case .missingID, .invalidID, .missingName, .alreadyExists, .cantDelete: .badRequest
        case .missingPermissions: .internalServerError
        }
    }

    var code: ErrorCode {
        switch self {
        case .notFound: 3001
        case .missingID: 3002
        case .invalidID: 3003
        case .missingName: 3004
        case .missingPermissions: 3005
        case .alreadyExists: 3006
        case .cantDelete: 3007
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingID: "Please provide a role ID and try again."
        case .invalidID: "Check that the role ID is valid and try again."
        case .cantDelete: "Remove all members before deleting a rol."
        default: nil
        }
    }
}

extension MinecraftServerError: ApplicationError {

    var description: String { errorDescription }

    var reason: String { errorDescription }

    var status: HTTPResponseStatus {
        switch self {
        case .unknown: .internalServerError
        case .notFound: .notFound
        case .invalidID: .badRequest
        case .alreadyExists: .conflict
        case .missingServerName: .badRequest
        case .missingServerType: .badRequest
        case .typeCantBeChanged: .badRequest
        case .invalidVersion: .badRequest
        case .invalidPort: .badRequest
        case .stopped: .badRequest
        case .running: .badRequest
        case .portAlreadyInUse: .locked
        case .tooManyRunningServers: .notAcceptable
        case .invalidCommand: .badRequest
        case .fileDoesNotExist: .notFound
        case .invalidPlayerAccount: .notFound
        case .systemError(_): .internalServerError
        }
    }

    var code: ErrorCode {
        switch self {
        case .unknown: 4000
        case .notFound: 4001
        case .invalidID: 4002
        case .alreadyExists: 4003
        case .missingServerName: 4004
        case .missingServerType: 4005
        case .typeCantBeChanged: 4006
        case .invalidVersion: 4007
        case .invalidPort: 4008
        case .stopped: 4009
        case .running: 4010
        case .portAlreadyInUse: 4011
        case .tooManyRunningServers: 4012
        case .invalidCommand: 4013
        case .fileDoesNotExist: 4014
        case .invalidPlayerAccount: 4015
        case .systemError(_): 4016
        }
    }
}

// MARK: - Swift errors

extension DecodingError: ApplicationError {
    var status: HTTPResponseStatus { .badRequest }
    var code: ErrorCode { 901 }
    var recoverySuggestion: String? { "Check the request data and try again." }
}
