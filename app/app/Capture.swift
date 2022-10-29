//
// Created by Emil Elton Nilsen on 29/10/2022.
//

import AVFoundation
import Combine
import CoreGraphics
import CoreImage
import CoreMotion
import Foundation
import UIKit
import os

struct Capture: Identifiable {

    let id: UInt32
    let photo: AVCapturePhoto

    var previewUIImage: UIImage? {
        makePreview()
    }

    var depthData: Data? = nil
    var gravity: CMAcceleration? = nil

    var uiImage: UIImage {
        UIImage(data: photo.fileDataRepresentation()!, scale: 1.0)!
    }

    init(id: UInt32, photo: AVCapturePhoto, depthData: Data? = nil, gravity: CMAcceleration? = nil) {
        self.id = id
        self.photo = photo
        self.depthData = depthData
        self.gravity = gravity
    }

    func writeAllFiles(to captureDir: URL) throws {
        writeImage(to: captureDir)
        writeGravityIfAvailable(to: captureDir)
        writeDepthIfAvailable(to: captureDir)
    }

    private var photoIdString: String {
        CaptureInfo.photoIdString(for: id)
    }

    private func makePreview() -> UIImage? {
        if let previewPixelBuffer = photo.previewPixelBuffer {
            let ciImage: CIImage = CIImage(cvPixelBuffer: previewPixelBuffer)
            let context: CIContext = CIContext(options: nil)
            let cgImage: CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: uiImage.imageOrientation)
        } else {
            return nil
        }
    }

    @discardableResult
    private func writeImage(to captureDir: URL) -> Bool {
        let imageUrl = CaptureInfo.imageUrl(in: captureDir, id: id)

        do {
            try photo.fileDataRepresentation()!.write(to: URL(fileURLWithPath: imageUrl.path), options: .atomic)
            return true
        } catch {
            print("Cant write image")
            return false
        }
    }

    @discardableResult
    private func writeGravityIfAvailable(to captureDir: URL) -> Bool {
        guard let gravityVector = gravity else {
            return false
        }

        let gravityString = String(format: "%lf,%lf,%lf", gravityVector.x, gravityVector.y, gravityVector.z)
        let gravityUrl = CaptureInfo.gravityUrl(in: captureDir, id: id)

        do {
            try gravityString.write(toFile: gravityUrl.path, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Cant write gravity url")
            return false
        }
    }

    @discardableResult
    private func writeDepthIfAvailable(to captureDir: URL) -> Bool {
        guard let depthMapData = depthData else {
            return false
        }

        let depthMapUrl = CaptureInfo.depthUrl(in: captureDir, id: id)
        do {
            try depthMapData.write(to: URL(fileURLWithPath: depthMapUrl.path), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
