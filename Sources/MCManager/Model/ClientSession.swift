//
//  ClientSession.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Vapor

struct ClientSession: Content {
    private(set) var accessToken: String
}
