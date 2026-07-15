//
//  ClientSession.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Information about the current user session.
struct ClientSession: Content {
    /// Access token for an authenticated user.
    private(set) var accessToken: String
}
