//
//  AuthenticationController.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import MCManager_Shared

struct AuthenticationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let login = routes.grouped(User.asyncCredentialsAuthenticator(), User.guardMiddleware())
        login.post("login") { req -> ClientSession in
            let requestUser = try req.content.decode(User.self)
            let user = try await User.query(on: req.db).all()
                .first(where: { $0.username == requestUser.username })
            guard let user,
                  let token = SessionToken.token(for: user)
            else {
                throw Abort(.unauthorized)
            }
            try await token.save(on: req.db)
            return .init(access: try req.jwt.sign(token))
        }
    }
}
