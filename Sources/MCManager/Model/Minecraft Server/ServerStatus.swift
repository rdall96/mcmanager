//
//  ServerStatus.swift
//  
//
//  Created by Ricky Dall'Armellina on 7/18/23.
//

import Foundation

extension MCServer {
    enum Status: String, Codable, CaseIterable {
        case unknown
        case stopped
        case starting
        case running
        case stopping
        case error
    }
}
