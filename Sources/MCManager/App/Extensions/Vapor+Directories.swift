//
//  Vapor+Directories.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Vapor
import Commands

extension DirectoryConfiguration {
    
    private var workingDirectoryURL: URL {
        URL(fileURLWithPath: workingDirectory)
    }

    /// Data diredtory to store all persistent pp data
    var dataDirectory: URL {
        get throws {
            let directory = workingDirectoryURL.appendingPathComponent("data", isDirectory: true)
            try FileManager.default.createDirectory(atPath: directory.path, withIntermediateDirectories: true)
            return directory
        }
    }
    
    /// Path to an object in the data directory
    func dataPath(for object: String) throws -> URL {
        try dataDirectory.appendingPathComponent(object)
    }
    
    /// Path to the default app database
    var defaultDatabasePath: URL {
        get throws {
            try dataPath(for: "db.sqlite")
        }
    }
    
    /// Path to the private key file
    var privateKeyPath: URL {
        get throws {
            try dataPath(for: "jwtRS256.key")
        }
    }
    
    /// Path to the public key file
    var publicKeyPath: URL {
        get throws {
            try privateKeyPath.appendingPathExtension("pub")
        }
    }
    
    func generateKeys(at path: URL) async throws {
        try await Shell.run("ssh-keygen -t rsa-sha2-256 -b 2048 -f \"\(path.path)\" -N \"mcmanager\"")
    }
    
    /// Path where the servers are stored
    var serversPath: URL {
        get throws {
            try dataPath(for: "servers")
        }
    }
}

fileprivate enum Shell {

    enum ShellError: Error {
        case commandFailed(String)
    }

    @discardableResult
    static func run(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let result = Commands.Bash.run(.init(command))
            if result.isFailure {
                continuation.resume(throwing: ShellError.commandFailed(result.errorOutput))
                return
            }
            continuation.resume(returning: result.output)
        }
    }
}
