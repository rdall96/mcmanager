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
    var description: String { "[\(code)]: \(reason)" }
    var errorDescription: String? { description }
    var failureReason: String? { reason }
}

// MARK: - MCManager errors

enum AuthenticationError: ApplicationError {
    case notAuthenticated
    case invalidCredentials

    var reason: String {
        switch self {
        case .notAuthenticated: "You are not logged in."
        case .invalidCredentials: "The provided credentials are invalid."
        }
    }

    var status: HTTPResponseStatus {
        switch self {
        case .notAuthenticated, .invalidCredentials: .unauthorized
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
    case missingID
    case invalidID(String)
    case notFound(User.IDValue)
    case unauthorized
    case adminRequired
    case cantDeleteAdmin
    case alreadyExists

    var reason: String {
        switch self {
        case .unknown: "An unknown error occurred."
        case .missingID: "A user ID is missing."
        case .invalidID(let string): "Invalid user ID: \(string)."
        case .notFound(let id): "No user found with ID: \(id)."
        case .unauthorized: "You do not have the necessary permissions to perform this action."
        case .adminRequired: "Only administrators can perform this action."
        case .cantDeleteAdmin: "You cannot delete the admin user."
        case .alreadyExists: "A user with that username already exists."
        }
    }

    var status: HTTPStatus {
        switch self {
        case .unknown: .internalServerError
        case .missingID, .invalidID: .badRequest
        case .notFound: .notFound
        case .unauthorized, .adminRequired: .forbidden
        case .cantDeleteAdmin: .badRequest
        case .alreadyExists: .badRequest
        }
    }

    var code: ErrorCode {
        switch self {
        case .unknown: 2000
        case .missingID: 2001
        case .invalidID: 2002
        case .notFound: 2003
        case .unauthorized: 2004
        case .adminRequired: 2005
        case .cantDeleteAdmin: 2006
        case .alreadyExists: 2007
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
    case missingID
    case invalidID(String)
    case notFound(Role.IDValue)
    case missingPermissions(Role)
    case alreadyExists

    var reason: String {
        switch self {
        case .missingID: "A role ID is missing."
        case .invalidID(let string): "Invalid role ID: \(string)."
        case .notFound(let id): "No role found with ID: \(id)."
        case .missingPermissions(let role): "Missing permissions (\(role.$_permissions.id)) found for role \(role.id?.uuidString ?? "unknown>")."
        case .alreadyExists: "A role with that name already exists."
        }
    }

    var status: HTTPResponseStatus {
        switch self {
        case .missingID, .invalidID, .alreadyExists: .badRequest
        case .notFound: .notFound
        case .missingPermissions: .internalServerError
        }
    }

    var code: ErrorCode {
        switch self {
        case .missingID: 3001
        case .invalidID: 3002
        case .notFound: 3003
        case .missingPermissions: 3004
        case .alreadyExists: 3005
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingID: "Please provide a role ID and try again."
        case .invalidID: "Check that the role ID is valid and try again."
        default: nil
        }
    }
}

extension MCServerError: ApplicationError {

    var reason: String { errorDescription ?? localizedDescription }

    var status: HTTPResponseStatus {
        switch self {
        case .unknown: .internalServerError
        case .invalidID: .badRequest
        case .notFound: .notFound
        case .invalidPort: .badRequest
        case .systemError: .internalServerError
        case .invalidAction: .badRequest
        case .invalidPlayerAccount: .badRequest
        }
    }

    var code: ErrorCode {
        switch self {
        case .unknown: 4000
        case .invalidID: 4001
        case .notFound: 4002
        case .invalidPort: 4003
        case .systemError: 4004
        case .invalidAction(let reason): // 4500...
            switch reason {
            case .serverIsStopped: 4500
            case .serverIsRunning: 4501
            case .serverAlreadyExists: 4502
            case .portAlreadyInUse: 4503
            case .invalidCommand: 4504
            case .tooManyRunningServers: 4505
            case .fileDoesNotExist: 4506
            }
        case .invalidPlayerAccount: 4005
        }
    }
}

// MARK: - Swift errors

extension DecodingError: ApplicationError {
    var status: HTTPResponseStatus { .badRequest }
    var code: ErrorCode { 901 }
    var recoverySuggestion: String? { "Check the request data and try again." }
}
