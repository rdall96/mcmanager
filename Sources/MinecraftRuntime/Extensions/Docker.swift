//
//  Docker.swift
//
//
//  Created by Ricky Dall'Armellina on 7/17/23.
//

import Foundation
import DockerSwift
import Commands

extension DockerClient.ImagesAPI {
    /// Query for available tags for a given image
    func query(image: String) -> Set<String> {
        let components = image.split(separator: "/")
        guard components.count == 2 else {
            return []
        }
        guard var url = URL(string: "https://hub.docker.com/v2/namespaces/\(components[0])/repositories/\(components[1])/tags") else {
            return []
        }
        var tags = Set<String>()
        while true {
            guard let results = query(url: url) else {
                break
            }
            tags.formUnion(results.results.compactMap({ $0.name }))
            if let nextUrl = results.next {
                url = nextUrl
            }
            else {
                break
            }
        }
        
        return tags
    }
    
    private func query(url: URL) -> DockerQueryResponse? {
        let result = Commands.Bash.run("curl \(url)")
        guard result.isSuccess, let data = result.output.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DockerQueryResponse.self, from: data)
    }
}

fileprivate struct DockerQueryResponse: Decodable {
    let count: UInt
    let next: URL?
    let previous: URL?
    let results: [Result]
}

extension DockerQueryResponse {
    struct Result: Decodable {
        let name: String
    }
}
