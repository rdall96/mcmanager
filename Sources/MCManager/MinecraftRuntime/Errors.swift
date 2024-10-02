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
    case invalidServerType
    case duplicateServer(UUID?)
    case executionError(String)
    case noServerRuntimeFound
    case downloadFailed
    case creationError
    case deletionError(String)
    case updateFailed(Error)
    case invalidIconData
    case missingServerProperties(URL)
    case corruptedServerProperties(URL, Error)
    case invalidServerProperty(String)
    case dockerError(Error)
    case failedToSendCommand
    
    var errorDescription: String? {
        switch self {
        case .systemError(_):
            return "System error"
        case .invalidServerId:
            return "Invalid server ID"
        case .invalidServerType:
            return "Invalid server type"
        case .duplicateServer(_):
            return "The server already exists"
        case .executionError(_):
            return "Server execution error"
        case .noServerRuntimeFound:
            return "No process found for the server"
        case .downloadFailed:
            return "Failed to download server"
        case .creationError:
            return "Failed to create server"
        case .deletionError(_):
            return "Failed to delete server"
        case .updateFailed(_):
            return "Failed to update server"
        case .invalidIconData:
            return "Icon data is invalid"
        case .missingServerProperties(_):
            return "Missing server properties file"
        case .corruptedServerProperties(_, _):
            return "Corrupted server properties"
        case .invalidServerProperty(_):
            return "Invalid server property name"
        case .dockerError(_):
            return "Unknown server runtime error"
        case .failedToSendCommand:
            return "An error occurred when sending the command to the server"
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
        case .invalidIconData:
            return "The icon data needs to be base64 encoded"
        case .missingServerProperties(let url):
            return "No server properties file found at \(url.path)"
        case .corruptedServerProperties(let url, let error):
            return "The server properties file at \(url.path) could not be read due to an error: \(error.localizedDescription)"
        case .invalidServerProperty(let string):
            return "\(string) is not a valid server property name"
        case .dockerError(let error):
            return "Docker threw an error: \(error.localizedDescription)"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .systemError(_), .executionError(_), .downloadFailed, .deletionError(_):
            return "Try aagin later"
        case .creationError, .updateFailed(_):
            return "Check that the provided server parameters are correct"
        default:
            return nil
        }
    }
}
