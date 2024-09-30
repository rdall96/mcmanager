//
//  UUID+String.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation

extension UUID {
    /// Return a string representation of the UUID that is safe to put in a system file path
    var pathSafeString: String {
        uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }
}
