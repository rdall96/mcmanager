//
//  Task.swift
//
//
//  Created by Ricky Dall'Armellina on 7/21/23.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: UInt) async throws {
        try await sleep(nanoseconds: UInt64(seconds) * UInt64(1e+9))
    }
}
