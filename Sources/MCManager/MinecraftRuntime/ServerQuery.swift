//
//  ServerQuery.swift
//
//
//  Created by Ricky Dall'Armellina on 8/17/23.
//

import Vapor

// Network is only available on Apple platforms
#if canImport(Network)
import Network
#endif // canImport(Network)

// FIXME: This does not work on linux because the `Network` library isn't available
final actor MinecraftServerQuery {
    
    private let query: UDPSession
    let sessionId: Int32
    
    init(port: MinecraftServer.Port, timeout: Int = 30) {
        query = .init(host: .localhost, port: port, timeout: timeout)
        sessionId = Int32.random() & 0x0F0F0F0F
    }
    
    private func send(_ request: ServerRequest) async throws -> Data {
        // ensure we are connected
        if !(await query.isConnected) {
            try await query.connect()
        }
        // send the request
        try await query.send(request.payload())
        // wait for a response
        return try await query.receive()
    }
    
    private func getToken() async throws -> Int32? {
        let response = try await send(
            ServerRequest(type: .handshake, session: sessionId)
        )
        
        // ignore the first 5 bytes: https://wiki.vg/Query#Response
        let responseBytes = [UInt8](response)[5...].map { $0 }
        // the challenge token is also null terminated: https://wiki.vg/Query#Response
        guard let tokenString = String(bytes: responseBytes, encoding: .utf8)?
            .replacingOccurrences(of: "\0", with: "")
        else {
            throw QueryError.handshakeFailed
        }
        
        return Int32(tokenString)
    }
    
    func getPlayers() async throws -> [String] {
        let token = try await getToken()
        let response = try await send(
            ServerRequest(type: .stats, session: sessionId, token: token)
        )
        
        // ignore the first 11 bytes: https://wiki.vg/Query#Response_3
        let responseBytes = [UInt8](response)[16...].map { $0 }
        guard let statsString = String(bytes: responseBytes, encoding: .utf8)
        else {
            throw QueryError.statsRequestFailed
        }
        
        // response structure: https://wiki.vg/Query#K.2C_V_section
        let components = statsString.split(separator: "\0")
            .map({ String($0) })
        
        // player list starts when we hit `\u{01}player_`
        let playerListIndex = components.firstIndex(of: "\u{01}player_")
        guard let playerListIndex, components.count > playerListIndex else {
            throw QueryError.statsRequestFailed
        }
        return components[(playerListIndex + 1)...].map({ String($0) })
    }
}

extension MinecraftServerQuery {
    enum QueryError: Error {
        case handshakeFailed
        case statsRequestFailed
    }
}

// MARK: - Request

fileprivate struct ServerRequest {
    let magicNumber: Array<UInt8> = [ 0xFE, 0xFD ]
    let type: RequestType
    let session: Int32
    let token: Int32?
    
    init(type: RequestType, session: Int32, token: Int32? = nil) {
        self.type = type
        self.session = session
        self.token = token
    }
    
    func payload(padding: Array<UInt8> = []) -> Data {
        var buffer = magicNumber
        buffer.append(type.rawValue)
        buffer.append(contentsOf: withUnsafeBytes(of: session.bigEndian) { Array($0) })
        if let token {
            buffer.append(contentsOf: withUnsafeBytes(of: token.bigEndian) { Array($0) })
        }
        if let padding = type.padding {
            buffer.append(contentsOf: padding)
        }
        return Data(buffer)
    }
}

extension ServerRequest {
    enum RequestType: UInt8 {
        case handshake = 0x09
        case stats = 0x00
        
        var padding: Array<UInt8>? {
            switch self {
            case .stats:
                return [ 0x00, 0x00, 0x00, 0x00 ]
            default:
                return nil
            }
        }
    }
}

// MARK: - UDP Session
fileprivate final actor UDPSession {
    
#if canImport(Network)
    private let connection: NWConnection
#endif // canImport(Network)
    
    let timeout: Int
    
    init(host: Address, port: MinecraftServer.Port, timeout: Int = 30) {
#if canImport(Network)
        connection = NWConnection(
            host: .init(host.rawValue),
            port: .init(integerLiteral: port.rawValue),
            using: .udp
        )
#endif // canImport(Network)
        self.timeout = timeout
    }
    
    var isConnected: Bool {
#if canImport(Network)
        connection.state == .ready
#else
        false // never connected for unsupported platforms
#endif // canImport(Network)
    }
    
    /// Create a connection to the host
    func connect() async throws {
#if canImport(Network)
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            let sem = DispatchSemaphore(value: 0)
            connection.stateUpdateHandler = { (newState) in
                switch (newState) {
                case .ready:
                    continuation.resume()
                    sem.signal()
                case .preparing, .setup:
                    break
                case .cancelled:
                    continuation.resume(throwing: UDPError.requestCancelled)
                    sem.signal()
                default:
                    continuation.resume(throwing: UDPError.connectionFailure)
                    sem.signal()
                }
            }
            connection.start(queue: .global(qos: .utility))
            let result = sem.wait(timeout: .now() + .seconds(timeout))
            guard result == .success else {
                continuation.resume(throwing: UDPError.timedOut)
                return
            }
        }
#else
        // return immediately on unsupported platforms
        return
#endif // canImport(Network)
    }
    
    /// Send data through the connection
    func send(_ data: Data) async throws {
#if canImport(Network)
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            let sem = DispatchSemaphore(value: 0)
            let completion: NWConnection.SendCompletion = .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: UDPError.sendError(error))
                    sem.signal()
                    return
                }
                continuation.resume()
                sem.signal()
            }
            connection.send(content: data, completion: completion)
            let result = sem.wait(timeout: .now() + .seconds(timeout))
            guard result == .success else {
                continuation.resume(throwing: UDPError.timedOut)
                return
            }
        }
#else
        // return immediately on unsupported platforms
        return
#endif // canImport(Network)
    }
    
    /// Receive data on the connection
    func receive() async throws -> Data {
#if canImport(Network)
        try await withUnsafeThrowingContinuation { continuation in
            let sem = DispatchSemaphore(value: 0)
            connection.receiveMessage { (data, context, isComplete, error) in
                if let error {
                    continuation.resume(throwing: UDPError.receiveError(error))
                    sem.signal()
                    return
                }
                guard isComplete, let data else {
                    continuation.resume(throwing: UDPError.receiveError(nil))
                    sem.signal()
                    return
                }
                continuation.resume(returning: data)
                sem.signal()
            }
            let result = sem.wait(timeout: .now() + .seconds(timeout))
            guard result == .success else {
                continuation.resume(throwing: UDPError.timedOut)
                return
            }
        }
#else
        // return empty data on unsupported platforms
        return Data()
#endif // canImport(Network)
    }
}

extension UDPSession {
    enum UDPError: Error {
        case timedOut
        case requestCancelled
        case connectionFailure
        case sendError(any Error)
        case receiveError((any Error)?)
    }
}

extension UDPSession {
    struct Address {
        let rawValue: String
        
        static let localhost: Self = .init(rawValue: "127.0.0.1")
    }
}
