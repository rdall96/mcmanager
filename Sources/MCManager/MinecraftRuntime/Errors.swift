//
//  Errors.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation

enum MCServerError: LocalizedError {
    case systemError(Error)
    case invalidServerId
    case duplicateServer(UUID?)
    case executionError(String)
    case creationError
    case deletionError(String)
    case updateFailed(Error)
    case corruptedServerProperties(URL, Error)
    case runtimeError(Error)
    case failedToSendCommand
    case serverIsRunning
    
    var errorDescription: String? {
        switch self {
        case .systemError(_):
            return "System error"
        case .invalidServerId:
            return "Invalid server ID"
        case .duplicateServer(_):
            return "The server already exists"
        case .executionError(_):
            return "Server execution error"
        case .creationError:
            return "Failed to create server"
        case .deletionError(_):
            return "Failed to delete server"
        case .updateFailed(_):
            return "Failed to update server"
        case .corruptedServerProperties(_, _):
            return "Corrupted server properties"
        case .runtimeError(_):
            return "A server runtime error occurred"
        case .failedToSendCommand:
            return "Failed to send command to the server"
        case .serverIsRunning:
            return "Can't perform this action while the server is running"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .systemError(let error):
            return "\(error)"
        case .duplicateServer(let uuid):
            return "A server with this ID (\(uuid?.uuidString ?? "-")) already exists"
        case .executionError(let string):
            return string
        case .deletionError(let string):
            return string
        case .updateFailed(let error):
            return error.localizedDescription
        case .corruptedServerProperties(_, let error):
            return "The server properties file could not be read due to an error: \(error.localizedDescription)"
        case .runtimeError(let error):
            return "Server runtime failure: \(error.localizedDescription)"
        case .serverIsRunning:
            return "This action can't be performed on a running server"
        default:
            return errorDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .systemError(_), .executionError(_), .deletionError(_), .failedToSendCommand:
            return "Try again later"
        case .creationError, .updateFailed(_):
            return "Check that the provided server parameters are correct"
        case .serverIsRunning:
            return "Stop the server and try again"
        default:
            return nil
        }
    }
}
