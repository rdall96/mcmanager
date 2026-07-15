//
//  Request+Helpers.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/11/26.
//

import Foundation
import Vapor

extension Client {
    /// Lookup Minecraft player information via: GET - https://api.mojang.com/users/profiles/minecraft/<playerName>
    func minecraftPlayerInfo(for name: String) async throws -> MinecraftPlayerInfo {
        let response = try await self.get("https://api.mojang.com/users/profiles/minecraft/\(name)")
        return try response.content.decode(MinecraftPlayerInfo.self)
    }
}
