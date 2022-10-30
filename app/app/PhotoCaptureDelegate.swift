//
// Created by Emil Elton Nilsen on 30/10/2022.
//

import AVFoundation
import CoreImage
import CoreMotion
import os

class PhotoCaptureProcessor: NSObject {
    private let photoId: UInt32
    private let model: CameraViewModel

    private(set) var requestPhotoSettings: AVCapturePhotoSettings

    private let willCapturePhotoAnimation: () -> Void

    lazy var context = CIContext()

    private let completionHandler: (PhotoCaptureProcessor) -> Void
    private let photoProcessingHandler: (Bool) -> Void

    private var maxPhotoProcessingTime: CMTime?

    private let motionManager: CMMotionManager

    private var photoData: AVCapturePhoto?
    private var depthMapData: Data?
    private var depthData: AVDepthData?
    private var gravity: CMAcceleration?

    init (
            with requestPhotoSettings: AVCapturePhotoSettings,
            model: CameraViewModel,
            photoId: UInt32,
            motionManager: CMMotionManager,
            willCapturePhotoAnimation: @escaping () -> Void,
            completionHandler: @escaping (PhotoCaptureProcessor) -> Void,
            photoProcessingHandler: @escaping (Bool) -> Void
    ) {
        self.photoId = photoId
        self.model = model
        self.motionManager = motionManager
        self.requestPhotoSettings = requestPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
    }

    private func didFinish() {
        completionHandler(self)
    }
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start + resolvedSettings.photoProcessingTimeRange.duration
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()

        if motionManager.isDeviceMotionActive {
            gravity = motionManager.deviceMotion?.gravity
        }

        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else { return }

        let oneSecond = CMTime(seconds: 1, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            photoProcessingHandler(true)
        }
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        photoProcessingHandler(false)

        if let error = error {
            photoData = nil
        } else {
            photoData = photo
        }

        if let depthData = photo.depthData?.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32),
           let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) {
            let depthImage = CIImage(cvImageBuffer: depthData.depthDataMap, options: [.auxiliaryDisparity: true])
            depthMapData = context.tiffRepresentation(
                    of: depthImage,
                    format: .Lf,
                    colorSpace: colorSpace,
                    options: [.disparityImage: depthImage]
            )
        } else {
            depthMapData = nil
        }
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        defer { didFinish() }

        if let error = error {
            print("Error capturing photo")
            return
        }

        guard let photoData = photoData else {
            print("No photo data resource")
            return
        }

        model.addCapture(Capture(id: photoId, photo: photoData, depthData: depthMapData, gravity: gravity))
    }
}
