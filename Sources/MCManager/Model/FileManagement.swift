//
//  FileManagement.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 10/2/24.
//

import Foundation
import Vapor
import Crypto
import NIOCore
import Zip

struct FileBrowser: Content {
    let path: String
    let files: [String]
    
    init(relativePath: String?, files: [String]) {
        self.path = (relativePath ?? "/")
            .replacingOccurrences(of: "//", with: "/")
        self.files = files
    }
}

enum FileType: String, Codable {
    case file
    case directory
}

struct FileUploadRequest: Codable {
    let filePath: String
    let fileType: FileType
    let checksum: String
    
    var fileName: String {
        filePath.split(separator: "/")
            .compactMap { String($0) }
            .last ?? filePath
    }
    
    var isCompressed: Bool {
        // Diurectories should always be zipped
        if case .directory = fileType {
            return true
        }
        else {
            return false
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case filePath = "path"
        case fileType = "type"
        case checksum = "checksum"
    }
}

final class FileUploadSession: @unchecked Sendable {

    private static let logger = Logger(label: "mcmanager-uploads")
    
    let request: Request
    private(set) var fileURL: URL
    let checksum: String
    let isCompressed: Bool
    
    init(for request: Request, metadata: FileUploadRequest) {
        self.request = request
        let fileExtension = metadata.isCompressed ? ".zip" : ""
        self.fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcmanager-upload-\(request.id)-\(metadata.fileName)\(fileExtension)")
        self.checksum = metadata.checksum
        self.isCompressed = metadata.isCompressed
    }
    
    deinit {
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private var eventLoop: any EventLoop {
        request.eventLoop
    }
    
    func get() async throws -> URL {
        let result = try await request.application.fileio.openFile(
            path: fileURL.path,
            mode: .write,
            flags: .allowFileCreation(),
            eventLoop: eventLoop
        ).flatMap {
            self.processUpload(fileHandle: $0)
        }.get()
        guard result else {
            throw Abort(.internalServerError)
        }
        
        // Read the saved file and check it's validity
        let data = try Data(contentsOf: fileURL)
        let sha256 = Array(Crypto.SHA256.hash(data: data).makeIterator())
            .map { String(format: "%02x", $0) }.joined()
        guard sha256 == checksum else {
            throw Abort(.badRequest)
        }
        
        if isCompressed {
            let unzipURL = try Zip.quickUnzipFile(fileURL)
            try? FileManager.default.removeItem(at: fileURL)
            // If the unzipped path only contains one item assume the whole directory was zipped,
            // and use that as the sourceFileURL
            if let unzippedContents = try? FileManager.default.contentsOfDirectory(atPath: unzipURL.path),
               unzippedContents.count == 1 {
                self.fileURL = unzipURL.appendingPathComponent(unzippedContents[0])
            }
            else {
                self.fileURL = unzipURL
            }
        }
        
        return fileURL
    }
    
    private func processUpload(fileHandle: NIOFileHandle) -> EventLoopFuture<Bool> {
        let promise = self.eventLoop.makePromise(of: Bool.self)
        let fileHandleBox = NIOLoopBound(fileHandle, eventLoop: self.eventLoop)
        
        self.request.body.drain { part in
            let fileHandle = fileHandleBox.value
            switch part {
            case .buffer(let byteBuffer):
                return self.request.application.fileio
                    .write(fileHandle: fileHandle, buffer: byteBuffer, eventLoop: self.eventLoop)
            case .error(let error):
                do {
                    Self.logger.critical("Failed to stream file")
                    try fileHandle.close()
                    promise.fail(error)
                }
                catch let fileError {
                    Self.logger.critical("Failed to close file upload")
                    promise.fail(fileError)
                }
                return self.eventLoop.makeSucceededFuture(())
            case .end:
                do {
                    try fileHandle.close()
                    promise.succeed(true)
                }
                catch {
                    Self.logger.critical("Failed to close file upload")
                    promise.fail(error)
                }
                return self.eventLoop.makeSucceededFuture(())
            }
        }
        
        return promise.futureResult
    }
}

final class FileDownloadSession {
    
    private static let logger = Logger(label: "mcmanager-downloads")
    
    let request: Request
    let url: URL
    let compressedFileURL: URL?
    
    init(for request: Request, url: URL) throws {
        self.request = request
        self.url = url
        
        // If the file is a folder, we should compress it
        if FileManager.default.isDirectory(at: url) {
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            let compressedFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("mcmanager-download-\(request.id)-\(url.lastPathComponent).zip")
            try Zip.zipFiles(
                paths: directoryContents,
                zipFilePath: compressedFileURL,
                password: nil,
                compression: .DefaultCompression,
                progress: nil
            )
            self.compressedFileURL = compressedFileURL
        }
        else {
            self.compressedFileURL = nil
        }
    }
    
    func get() -> Response {
        let downloadURL: URL = compressedFileURL ?? url
        return request.fileio.streamFile(at: downloadURL.path, mediaType: HTTPMediaType(for: downloadURL)) { _ in
            if let compressedFileURL = self.compressedFileURL {
                try? FileManager.default.removeItem(at: compressedFileURL)
            }
        }
    }
}

fileprivate extension FileManager {
    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}

fileprivate extension HTTPMediaType {
    init(for url: URL) {
        switch url.pathExtension.lowercased() {
        case "png":
            self = .png
        case "jar":
            self = HTTPMediaType(type: "application", subType: "java-archive")
        case "json":
            self = .json
        case "txt":
            self = HTTPMediaType(type: "text", subType: "plain")
        case "zip":
            self = .zip
        default:
            // TODO: Get more file extensions from `fileExtensionMediaTypeMapping` in the `HTTPMediaType` source
            self = .any
        }
    }
}
