//
//  CORSMiddleware.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 11/13/25.
//

import Foundation
import Vapor

struct WebAppCORSMiddleware: Middleware {
    private let cors: CORSMiddleware

    init(defaultPort: UInt = 3000) {
        var port: UInt = defaultPort
        if let uiPortValue = Environment.get("WEB_APP_PORT"),
           let customUIPort = UInt(uiPortValue) {
            port = customUIPort
        }

        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .any([
                "127.0.0.1:\(port)",
                "http://localhost:\(port)"
            ]),
            allowedMethods: [.GET, .POST, .PUT, .DELETE],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin],
            allowCredentials: true
        )
        cors = CORSMiddleware(configuration: corsConfiguration)
    }

    func respond(to request: Vapor.Request, chainingTo next: any Vapor.Responder) -> NIOCore.EventLoopFuture<Vapor.Response> {
        cors.respond(to: request, chainingTo: next)
    }
}
