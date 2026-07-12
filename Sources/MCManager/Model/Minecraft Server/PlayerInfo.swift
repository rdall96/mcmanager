//
//  PlayerInfo.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/11/26.
//

import Foundation
import Vapor

/// Information regarding a Minecraft player.
/// See: GET - https://api.mojang.com/users/profiles/minecraft/<player_name>
struct MCPlayerInfo: Identifiable, Hashable, Content {
    let id: UUID?
    let name: String

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }

    // Minecraft's API is etremely inconsistent.
    // Sometimes, they use encode a true UUID, sometimes, a version without the dashes.
    // In the case of this object it's without dashes, but we want the `id` member to play nice with all the other
    // Swift UUID types, so we need custom decoding to handle the format differences.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            guard let uuid = UUID(string: id) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid Minecraft user ID \(id)"))
            }
            self.id = uuid
        }
        else {
            self.id = nil
        }
        self.name = try container.decode(String.self, forKey: .name)
    }
}

fileprivate extension UUID {
    init?(string: String) {
        // fd3a8ccf-1805-4ebc-a12d-159e35baa909
        if string.count == 36 {
            self.init(uuidString: string)
        }
        // fd3a8ccf18054ebca12d159e35baa909
        else if string.count == 32 {
            // insert dashes
            let chunks = [8, 4, 4, 4, 12]
            var result = ""
            var index = string.startIndex
            for (i, length) in chunks.enumerated() {
                let end = string.index(index, offsetBy: length)
                result += string[index..<end]
                if i < chunks.count - 1 { result += "-" }
                index = end
            }
            self.init(uuidString: result)
        }
        else {
            return nil
        }
    }
}
