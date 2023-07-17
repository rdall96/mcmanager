//
//  Orchestra.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
@_spi(MCManager_Runtime) import MCManager_Shared
import DockerSwift

/**
 The orchestra is an object that manages all the server runtimes on the current host
 */
public final class ServerOrchestra {
    
    private let serversRoot: URL
    private var servers: [ServerRuntime]
    private var statusUpdaterTask: Task<Void, Never>?
    
    private let docker: DockerClient
    
    init(serversRoot: URL) async throws {
        // create the servers root directory if it doesn't exist
        self.serversRoot = serversRoot
        try FileManager.default.createDirectory(at: serversRoot, withIntermediateDirectories: true)
        
        servers = []
        statusUpdaterTask = nil
        
        // create a docker client to use for server execution
        docker = DockerClient()
        // ensure this host has access to docker
        do {
            try await docker.ping()
        }
        catch {
            throw MCRError.dockerError(error)
        }
    }
    
    deinit {
        statusUpdaterTask?.cancel()
        statusUpdaterTask = nil
        
        // close the docker client connection
        do {
            try docker.syncShutdown()
        }
        catch {
            // TODO: Log an error if we fail to shutdown docker
        }
    }
    
    /// Clean up unused files on the system
    func cleanup() async throws {
        // prunes unused docker images
        do {
            _ = try await docker.images.prune()
            _ = try await docker.containers.prune()
        }
        catch {
            throw MCRError.dockerError(error)
        }
        // remove the files for unused servers
        let allServersOnDisk = try FileManager.default.contentsOfDirectory(
            at: serversRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsSubdirectoryDescendants
        )
        let unusedServersOnDisk: [URL] = allServersOnDisk.compactMap {
            guard let uuid = UUID(uuidString: $0.lastPathComponent),
                  !servers.contains(where: { $0.id == uuid })
            else {
                return nil
            }
            return $0
        }
        for unusedServerPath in unusedServersOnDisk {
            try FileManager.default.removeItem(at: unusedServerPath)
        }
    }
    
    // MARK: - Server status updates
    
    private static func createStatusUpdateJob() -> Task<Void, Never> {
        return Task(priority: .background) { @MainActor in
            print("Hello")
        }
    }
    
    func enableStatusUpdates() {
        if servers.isEmpty, statusUpdaterTask != nil {
            statusUpdaterTask?.cancel()
        }
        statusUpdaterTask = servers.isEmpty ? nil : Self.createStatusUpdateJob()
    }
    
    // MARK: - Server management
    
    /// Add a server to the orchestra, if it doesn't exist, this methods creates the new server
    func add(server: Server) async throws {
        // ensure this server doesn't already exist
        guard servers.compactMap({ $0.id }).contains(server.id) else {
            throw MCRError.duplicateServer(server.id)
        }
        let runtime = try await ServerRuntime(info: server, rootPath: serversRoot, docker: docker)
        servers.append(runtime)
    }
    
    private func index(for id: UUID?) throws -> Int {
        guard let index = servers.firstIndex(where: { $0.id == id }) else {
            throw MCRError.invalidServerId
        }
        return index
    }
    
    /// Update the info for the given server
    func update(server: Server) async throws {
        let index = try index(for: server.id)
        try await servers[index].update(server)
    }
    
    /// Delete a server
    func delete(server: Server) async throws {
        let index = try index(for: server.id)
        try await servers[index].delete()
        servers.remove(at: index)
    }
    
    // MARK: - Creation
    
    /// Get information regarding all supported runtimes that can be used to create new servers
    var allSupportedRuntimes: [Server.RuntimeSupport] {
        get async throws {
            var result: [Server.RuntimeSupport] = []
            let allTags  = docker.images.query(image: ServerRuntime.dockerImageName)
            for serverType in Server.ServerType.allCases {
                let tags: [String] = allTags.lazy
                    .filter { $0.contains(serverType.dockerTagName) }
                    .sorted()
                    .reversed()
                result.append(.init(
                    type: serverType,
                    versions: tags
                ))
            }
            return result
        }
    }
    
    // MARK: - Status
    
    // MARK: - Properties & config
    
    // MARK: - Execution
}
