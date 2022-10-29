//
// Created by Emil Elton Nilsen on 29/10/2022.
//

import Combine
import Foundation
import os

struct CaptureInfo: Identifiable {

    struct FileExistence {
        var image: Bool = false
        var depth: Bool = false
        var gravity: Bool = false
    }

    enum Error: Swift.Error {
        case invalidPhotoString
        case noSuchDirectory(URL)
    }

    static let imageSuffix: String = ".HEIC"

    let id: UInt32
    let captureDir: URL

    init(id: UInt32, captureDir: URL) {
        self.id = id
        self.captureDir = captureDir
    }

    var photoIdString: String {
        CaptureInfo.photoIdString(for: id)
    }

    var imageUrl: URL {
        CaptureInfo.imageUrl(in: captureDir, id: id)
    }

    var depthUrl: URL {
        CaptureInfo.depthUrl(in: captureDir, id: id)
    }

    var gravityUrl: URL {
        CaptureInfo.gravityUrl(in: captureDir, id: id)
    }

    func checkFilesExist() -> Future<FileExistence, CaptureInfo.Error> {
        let future = Future<FileExistence, CaptureInfo.Error> { promise in
            CaptureInfo.loaderQueue.async {
                guard CaptureInfo.doesDirectoryExist(url: captureDir) else {
                    promise(.failure(CaptureInfo.Error.noSuchDirectory(captureDir)))
                    return
                }
                do {
                    let existence = try CaptureInfo.checkFilesExist(inFolder: captureDir, id: id)
                    promise(.success(existence))
                } catch {
                    promise(.failure(CaptureInfo.Error.noSuchDirectory(captureDir)))
                }
            }
        }
        return future
    }

    func deleteAllFiles() {
        dispatchPrecondition(condition: .notOnQueue(.main))
        deleteHelper(delete: imageUrl, fileType: "image")
        deleteHelper(delete: depthUrl, fileType: "depth")
        deleteHelper(delete: gravityUrl, fileType: "gravity")
    }

    private func deleteHelper(delete: URL, fileType: String) {
        do {
            try FileManager.default.removeItem(atPath: delete.path)
        } catch {
            print("Not able to delete helper")
        }
    }

    static func checkFilesExist(inFolder captureDir: URL, id: UInt32) throws -> FileExistence {
        dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))

        guard CaptureInfo.doesDirectoryExist(url: captureDir) else {
            throw Error.noSuchDirectory(captureDir)
        }

        var result = FileExistence()
        result.image = FileManager.default.fileExists(atPath: imageUrl(in: captureDir, id: id).path)
        result.depth = FileManager.default.fileExists(atPath: depthUrl(in: captureDir, id: id).path)
        result.gravity = FileManager.default.fileExists(atPath: gravityUrl(in: captureDir, id: id).path)

        return result
    }

    static private func doesDirectoryExist(url: URL) -> Bool {
        guard url.isFileURL else { return false }
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        return isDirectory.boolValue
    }

    static func extractId(from photoString: String) throws -> UInt32 {
        guard let endOfPrefix = photoString.lastIndex(of: "_") else {
            throw Error.invalidPhotoString
        }

        let imgPrefix = photoString[...endOfPrefix]
        guard imgPrefix == CaptureInfo.photoStringPrefix else {
            throw Error.invalidPhotoString
        }

        guard let id = UInt32(photoString[photoString.index(after: endOfPrefix)...]) else {
            throw Error.invalidPhotoString
        }

        return id
    }

    static func photoIdString(for id: UInt32) -> String {
        String(format: "%@%04d", photoStringPrefix, id)
    }

    static func photoIdString(from imageUrl: URL) throws -> String {
        let basename = imageUrl.lastPathComponent

        guard basename.hasSuffix(imageSuffix), let suffixStartIndex = basename.lastIndex(of: ".") else {
            throw Error.invalidPhotoString
        }

        return String(basename[..<suffixStartIndex])
    }

    static func imageUrl(in captureDir: URL, id: UInt32) -> URL {
        captureDir.appendingPathComponent(photoIdString(for: id).appending(imageSuffix))
    }

    static func gravityUrl(in captureDir: URL, id: UInt32) -> URL {
        captureDir.appendingPathComponent(photoIdString(for: id).appending("_gravity.TXT"))
    }

    static func depthUrl(in captureDir: URL, id: UInt32) -> URL {
        captureDir.appendingPathComponent(photoIdString(for: id).appending("_depth.TIF"))
    }

    private static let loaderQueue = DispatchQueue(label: "no.emileni.app.CaptureInfo.loaderQueue", qos: .userInitiated)

    private static let photoStringPrefix = "IMG_"
}
