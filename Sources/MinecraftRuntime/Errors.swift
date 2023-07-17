//
//  Errors.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation

public enum MCRError: LocalizedError {
    case invalidServerId
    case invalidServerType
    case duplicateServer(UUID?)
    case executionError(String)
    case downloadFailed
    case creationError
    case deletionError(String)
    case updateFailed(Error)
    case invalidIconData
    case missingServerConfig(URL)
    case corruptedServerConfiguration(URL, Error)
    case invalidServerConfigKey(String)
    case dockerError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidServerId:
            return "Invalid server ID"
        case .invalidServerType:
            return "Invalid server type"
        case .duplicateServer(_):
            return "The server already exists"
        case .executionError(_):
            return "Server execution error"
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
        case .missingServerConfig(_):
            return "Missing server configuration"
        case .corruptedServerConfiguration(_, _):
            return "Corrupted server configuration"
        case .invalidServerConfigKey(_):
            return "Invalid server configuration key"
        case .dockerError(_):
            return "Unknown server runtime error"
        }
    }
    
    public var failureReason: String? {
        switch self {
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
        case .missingServerConfig(let url):
            return "No server configuration (aka: server properties) found at \(url.path)"
        case .corruptedServerConfiguration(let url, let error):
            return "The server configuration at \(url.path) could not be read due to an error: \(error.localizedDescription)"
        case .invalidServerConfigKey(let string):
            return "\(string) is not a valid server configuration key"
        case .dockerError(let error):
            return "Docker threw an error: \(error.localizedDescription)"
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .executionError(_), .downloadFailed, .deletionError(_):
            return "Try aagin later"
        case .creationError, .updateFailed(_):
            return "Check that the provided server parameters are correct"
        default:
            return nil
        }
    }
}
