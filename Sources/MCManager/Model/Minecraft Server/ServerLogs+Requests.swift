//
//  ServerLogs+Requests.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/15/26.
//

import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// Optional parameters to fetch the server logs.
struct MinecraftServerFetchLogsRequest: Content {
    /// The number of most recent logs to include the response.
    let tail: UInt?
}
