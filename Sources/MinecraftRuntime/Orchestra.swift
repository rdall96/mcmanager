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
    private var serverRuntimes: [UUID : ServerRuntime]
    private var statusUpdaterTask: Task<Void, Never>?
    
    private let docker: DockerClient
    
    public init(serversRoot: URL) async throws {
        // create the servers root directory if it doesn't exist
        self.serversRoot = serversRoot
        try FileManager.default.createDirectory(at: serversRoot, withIntermediateDirectories: true)
        
        serverRuntimes = [:]
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
    public func cleanup() async throws {
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
        let unusedServersOnDisk: [URL] = allServersOnDisk.filter {
            guard let uuid = UUID(uuidString: $0.lastPathComponent) else { return false }
            return serverRuntimes[uuid] == nil
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
    
    private func enableStatusUpdates() {
        if serverRuntimes.isEmpty, statusUpdaterTask != nil {
            statusUpdaterTask?.cancel()
        }
        statusUpdaterTask = serverRuntimes.isEmpty ? nil : Self.createStatusUpdateJob()
    }
    
    // MARK: - Server management
    
    private func requireId(for server: Server) throws -> UUID {
        guard let uuid = server.id,
              serverRuntimes[uuid] != nil
        else {
            throw MCRError.invalidServerId
        }
        return uuid
    }
    
    private func requireServer(withId uuid: UUID) throws -> ServerRuntime {
        guard let serverRuntime = serverRuntimes[uuid] else {
            throw MCRError.invalidServerId
        }
        return serverRuntime
    }
    
    /// Add a server to the orchestra, if it doesn't exist, this methods creates the new server
    public func add(server: Server) async throws {
        // ensure this server doesn't already exist
        guard let serverId = server.id else {
            throw MCRError.invalidServerId
        }
        guard serverRuntimes[serverId] == nil else { throw MCRError.duplicateServer(serverId) }
        let runtime = try await ServerRuntime(info: server, rootPath: serversRoot, docker: docker)
        serverRuntimes[serverId] = runtime
    }
    
    /// Update the info for the given server
    public func update(server: Server) async throws {
        let serverId = try requireId(for: server)
        try await serverRuntimes[serverId]?.update(server)
    }
    
    /// Delete a server by ID
    public func delete(serverWithId uuid: UUID) async throws {
        _ = try requireServer(withId: uuid)
        try await serverRuntimes[uuid]?.delete()
        serverRuntimes.removeValue(forKey: uuid)
    }
    
    // MARK: - Creation
    
    /// Get information regarding all supported runtimes that can be used to create new servers
    public var allSupportedRuntimes: [Server.RuntimeSupport] {
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
    
    /// Get the status for a specific server
    public func info(for serverId: UUID) async throws -> Server.Info {
        let server = try requireServer(withId: serverId)
        return await server.info
    }
    
    // MARK: - Properties & config
    
    /// Get the server config (aka server properties)
    func config(for serverId: UUID) async throws -> Set<Server.Config> {
        let server = try requireServer(withId: serverId)
        return await server.config
    }
    
    /// Update the config for a server
    func updateConfig(_ config: Set<Server.Config>, for serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.updateConfig(config)
    }
    
    /// Get the icon for a server
    func icon(for serverId: UUID) async throws -> String? {
        let server = try requireServer(withId: serverId)
        return await server.icon
    }
    
    /// Update the server icon
    func updateIcon(_ iconData: String, for serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.updateIcon(iconData)
    }
    
    /// Remove the server icon
    func removeIcon(for serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        await server.removeIcon()
    }
    
    // MARK: - Execution
    
    /// Start a server
    func start(serverWithId serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.start()
    }
    
    /// Stop a server
    func stop(serverWithId serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.stop()
    }
    
    /// Restart a server
    func restart(serverWithId serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.restart()
    }
    
    func send(command: String, to serverId: UUID) async throws {
        let server = try requireServer(withId: serverId)
        try await server.send(command: command)
    }
    
    func logs(for serverId: UUID, tail: UInt? = nil) async throws -> String {
        let server = try requireServer(withId: serverId)
        return try await server.logs(tail: tail)
    }
}
