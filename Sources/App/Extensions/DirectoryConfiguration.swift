//
//  File.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Vapor

extension DirectoryConfiguration {
    
    /// Data diredtory to store all persistent pp data
    var dataDirectory: String {
        get throws {
            let directory = workingDirectory + (workingDirectory.last == "/" ? "data/" : "/data/")
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            return directory
        }
    }
    
    /// Path to an object in the data directory
    func dataPath(for object: String) throws -> String {
        try dataDirectory + object
    }
    
    /// Path to the default app database
    var defaultDatabasePath: String {
        get throws {
            try dataPath(for: "db.sqlite")
        }
    }
    
    /// Path to the private key file
    var privateKeyPath: String {
        get throws {
            try dataPath(for: "jwtRS256.key")
        }
    }
    
    /// Path to the public key file
    var publicKeyPath: String {
        get throws {
            try privateKeyPath + ".pub"
        }
    }
    
    func generateKeys(at path: String) {
        Shell.run("ssh-keygen -t rsa-sha2-256 -b 2048 -f \"\(path)\" -N \"mcmanager\"")
    }
}
