//
//  ServerStatus.swift
//
//
//  Created by Ricky Dall'Armellina on 7/20/23.
//

import Foundation
import MCManager_Shared
import DockerSwiftAPI

extension Server.Status {
    init(with status: Docker.Container.Status) {
        switch status {
        case .created, .exited, .paused:
            self = .stopped
        case .running:
            self = .running
        case .restarting:
            self = .starting
        case .unknown:
            self = .error
        }
    }
}
