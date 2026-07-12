//
//  RuntimeErrors.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation

enum MCServerError: LocalizedError {

    /// Reason for an invalid action.
    enum Reason {
        case serverIsStopped
        case serverIsRunning
        case serverAlreadyExists
        case portAlreadyInUse
        case invalidCommand
        case tooManyRunningServers
        case fileDoesNotExist
    }

    case unknown
    case invalidID(String?)
    case notFound(MCServer.IDValue)
    case invalidPort(MCServer.Port)
    case systemError(Error)
    case invalidAction(Reason)
    case invalidPlayerAccount

    @_disfavoredOverload
    static func invalidID(_ uuid: UUID?) -> Self {
        .invalidID(uuid?.uuidString)
    }

    var errorDescription: String? {
        switch self {
        case .unknown: "An unknown error occurred."
        case .invalidID(let string): "Invalid server ID: \(string ?? "<none>")."
        case .notFound(let id): "Server with id \(id) not found."
        case .invalidPort(let port): "Invalid server port: \(port). Please choose a port in the allowed port range and try again."
        case .systemError(let error): "An error occurred! \(error.localizedDescription)"
        case .invalidAction(let reason):
            switch reason {
            case .serverIsStopped: "The server is not running."
            case .serverIsRunning: "The server is currently running."
            case .serverAlreadyExists: "A server with this ID already exists."
            case .portAlreadyInUse: "This port is currently in use by another server."
            case .invalidCommand: "The provided command is not a valid server command."
            case .tooManyRunningServers: "You have reached the maximum number servers that can run simultaneously."
            case .fileDoesNotExist: "The requested server file does not exist."
            }
        case .invalidPlayerAccount: "The requested Minecraft account does not exist."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unknown: "Please try again later."
        case .invalidID, .notFound: "Please provide a valid server ID."
        case .invalidPort: "Please choose a port in the allowed port range and try again."
        case .systemError: nil
        case .invalidAction(let reason):
            switch reason {
            case .serverIsStopped: "Start the server and try again."
            case .serverIsRunning: "Stop the server and try again."
            case .serverAlreadyExists: nil
            case .portAlreadyInUse: "Try stopping the server that is currently using this port or edit the current server to choose a different port. Then try again."
            case .invalidCommand: "Please provide a valid server command."
            case .tooManyRunningServers: "Stop one or more servers and try again."
            case .fileDoesNotExist: "Please choose a file that actually exists."
            }
        case .invalidPlayerAccount: "The requested Minecraft account does not exist."
        }
    }
}
