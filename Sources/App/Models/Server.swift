//
//  Server.swift
//
//
//  Created by Ricky Dall'Armellina on 7/14/23.
//

import Fluent
import Vapor
import MCManager_Shared

extension MCManager_Shared.Server: Content {}

extension MCManager_Shared.Server.ServerType: Content {}

extension MCManager_Shared.Server.Version: Content {}

extension MCManager_Shared.Server.Info: Content {}

extension MCManager_Shared.Server.Metrics: Content {}

extension MCManager_Shared.Server.Config: Content {}

extension MCManager_Shared.Server.Icon: Content {}

extension MCManager_Shared.Server.RuntimeSupport: Content {}
