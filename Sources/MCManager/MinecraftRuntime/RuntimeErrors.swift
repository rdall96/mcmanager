//
//  RuntimeErrors.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation

enum MinecraftServerError: LocalizedError {

    case unknown
    case notFound
    case invalidID
    case alreadyExists
    case missingServerName
    case missingServerType
    case typeCantBeChanged
    case invalidVersion
    case invalidPort
    case stopped
    case running
    case portAlreadyInUse
    case tooManyRunningServers
    case invalidCommand
    case fileDoesNotExist
    case invalidPlayerAccount
    case systemError(Error)

    var errorDescription: String {
        switch self {
        case .unknown: "An unknown error occurred."
        case .notFound: "Server not found."
        case .invalidID: "Invalid server ID."
        case .alreadyExists: "Server already exists."
        case .missingServerName: "Missing server name."
        case .missingServerType: "Missing server type."
        case .typeCantBeChanged: "The server type cannot be changed."
        case .invalidVersion: "Invalid game version."
        case .invalidPort: "Invalid server port."
        case .stopped: "The server is stopped."
        case .running: "The server is running."
        case .portAlreadyInUse: "This port is currently in use by another server."
        case .tooManyRunningServers: "You have reached the maximum number servers that can run simultaneously."
        case .invalidCommand: "The provided command is not a valid server command."
        case .fileDoesNotExist: "The requested server file does not exist."
        case .invalidPlayerAccount: "The requested Minecraft account does not exist."
        case .systemError(let error): "An runtime occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .stopped: "Start the server and try again."
        case .running: "Stop the server and try again."
        case .portAlreadyInUse: "Change the server port or stop the server that is currently using this port."
        default: nil
        }
    }
}
