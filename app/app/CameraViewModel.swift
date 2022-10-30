//
// Created by Emil Elton Nilsen on 29/10/2022.
//

import AVFoundation
import Combine
import CoreMotion
import SwiftUI

import os

class CameraViewModel: ObservableObject {
    var session: AVCaptureSession

    enum CaptureMode {
        case manual
        case automatic(everySecs: Double)
    }

    @Published var lastCapture: Capture? = nil
    @Published var isCameraAvailable: Bool = false
    @Published var isHighQualityMode: Bool = false
    @Published var isDepthDataEnabled: Bool = false
    @Published var isMotionDataEnabled: Bool = false
    @Published var captureFolderState: CaptureFolderState?

    @Published var captureMode: CaptureMode = .manual {
        willSet(newMode) {
            if case .automatic = captureMode {
                stopAutomaticCapture()
                triggerEveryTimer = nil
            }
        }

        didSet {
            if case .automatic(let intervalSecs) = captureMode {
                autoCaptureIntervalSecs = intervalSecs
                triggerEveryTimer = TriggerEveryTimer(
                        triggerEvery: autoCaptureIntervalSecs,
                        onTrigger: {
                            self.capturePhotoAndMetadata()
                        },
                        updateEvery: 1.0 / 30.0, // 30 fps
                        onUpdate: { timeLeft in
                            self.timeUntilCaptureSecs = timeLeft
                        }
                )
            }
        }
    }

    @Published var isAutoCaptureActive: Bool = false
    @Published var timeUntilCaptureSecs: Double = 0

    var autoCaptureIntervalSecs: Double = 0

    var readyToCapture: Bool {
        captureFolderState != nil
                && captureFolderState!.captures.count < CameraViewModel.maxPhotosAllowed
                && self.inProgressPhotoCaptureDelegates.count < 2
    }

    var captureDir: URL? {
        captureFolderState?.captureDir
    }

    static let maxPhotosAllowed = 250
    static let recommendedMinPhotos = 30
    static let recommendedMaxPhotos = 200
    static let defaultAutomaticCaptureIntervalSecs: Double = 3.0

    init() {
        session = AVCaptureSession()

        startSetup()
    }

    func advanceToNextCaptureMode() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        switch captureMode {
        case .manual:
            captureMode = .automatic(everySecs: CameraViewModel.defaultAutomaticCaptureIntervalSecs)
        case .automatic(_):
            captureMode = .manual
        }
    }

    func captureButtonPressed() {
        switch captureMode {
        case .manual:
            capturePhotoAndMetadata()
        case .automatic:
            guard triggerEveryTimer != nil else { return }
            if triggerEveryTimer!.isRunning {
                stopAutomaticCapture()
            } else {
                startAutomaticCapture()
            }
        }
    }

    func requestNewCaptureFolder() {
        DispatchQueue.main.async {
            self.lastCapture = nil
        }

        sessionQueue.async {
            do {
                let newCaptureFolder = try CameraViewModel.createNewCaptureFolder()
                DispatchQueue.main.async {
                    self.captureFolderState = newCaptureFolder
                }
            } catch {
                print("Cannot create new capture folder")
            }
        }
    }

    func addCapture(_ capture: Capture) {
        DispatchQueue.main.async {
            self.lastCapture = capture
        }

        guard self.captureDir != nil else { return }

        sessionQueue.async {
            do {
                try capture.writeAllFiles(to: self.captureDir!)
                self.captureFolderState?.requestLoad()
            } catch {
                print("Cannot write capture")
            }
        }
    }

    func removeCapture(captureInfo: CaptureInfo, deleteData: Bool = true) {
        captureFolderState?.removeCapture(captureInfo: captureInfo, deleteData: deleteData)
    }

    func startSetup() {
        do {
            captureFolderState = try CameraViewModel.createNewCaptureFolder()
        } catch {
            setupResult = .cantCreateOutputDirectory
            print("Setup failed")
            return
        }

        requestAuthorizationIfNeeded()
        sessionQueue.async {
            self.configureSession()
        }

        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates()
            DispatchQueue.main.async {
                self.isMotionDataEnabled = true
            }
        } else {
            DispatchQueue.main.async {
                self.isMotionDataEnabled = false
            }
        }
    }

    func startSession() {
        dispatchPrecondition(condition: .onQueue(.main))
        sessionQueue.async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }

    func pauseSession() {
        dispatchPrecondition(condition: .onQueue(.main))
        sessionQueue.async {
            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
        }
        if isAutoCaptureActive {
            stopAutomaticCapture()
        }
    }

    let previewWidth = 512
    let previewHeight = 512
    let thumbnailWidth = 512
    let thumbnailHeight = 512

    private var photoId: UInt32 = 0
    private var photoQualityPrioritizationMode : AVCapturePhotoOutput.QualityPrioritization = .quality

    private static let cameraShutterNoiseID: SystemSoundID = 1108

    private enum SessionSetupResult {
        case inProgress
        case success
        case cantCreateOutputDirectory
        case notAuthorized
        case configurationFailed
    }

    private enum SessionSetupError: Swift.Error {
        case cantCreateOutputDirectory
        case notAuthorized
        case configurationFailed
    }

    private enum SetupError: Error {
        case failed(msg: String)
    }

    private var setupResult: SessionSetupResult = .inProgress {
        didSet {
            if case .inProgress = setupResult { return }
            if case .success = setupResult {
                DispatchQueue.main.async {
                    self.isCameraAvailable = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
            }
        }
    }

    private var videoDeviceInput: AVCaptureDeviceInput? = nil
    private var isSessionRunning = false

    private let sessionQueue = DispatchQueue(label: "CameraViewModel: sessionQueue")
    private let motionManager = CMMotionManager()

    private var photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    private var triggerEveryTimer: TriggerEveryTimer? = nil

    private func capturePhotoAndMetadata() {
        dispatchPrecondition(condition: .onQueue(.main))

        let videoPreviewLayerOrientation = session.connections[0].videoOrientation

        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
            }

            var photoSettings = AVCapturePhotoSettings()

            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }

            if self.videoDeviceInput!.device.isFlashAvailable {
                photoSettings.flashMode = .off
            }

            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
            photoSettings.embedsDepthDataInPhoto = true

            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!,
                    kCVPixelBufferWidthKey: self.previewWidth,
                    kCVPixelBufferHeightKey: self.previewHeight
                ] as [String: Any]
                print("Found preview photo")
            } else {
                print("Cant find preview photo")
            }

            photoSettings.embeddedThumbnailPhotoFormat = [
                AVVideoCodecKey: AVVideoCodecType.jpeg,
                AVVideoWidthKey: self.thumbnailWidth,
                AVVideoHeightKey: self.thumbnailHeight
            ]

            DispatchQueue.main.async {
                self.isHighQualityMode =
                        photoSettings.isHighResolutionPhotoEnabled
                        && photoSettings.photoQualityPrioritization == .quality
            }

            self.photoId += 1

            let photoCaptureProcessor = self.makeNewPhotoCaptureProcessor(photoId: self.photoId, photoSettings: photoSettings)
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestPhotoSettings.uniqueID] = photoCaptureProcessor

            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }

    private func makeNewPhotoCaptureProcessor(photoId: UInt32, photoSettings: AVCapturePhotoSettings) -> PhotoCaptureProcessor {
        let photoCaptureProcessor = PhotoCaptureProcessor(
                with: photoSettings,
                model: self,
                photoId: photoId,
                motionManager: self.motionManager,
                willCapturePhotoAnimation: {
                    AudioServicesPlaySystemSound(CameraViewModel.cameraShutterNoiseID)
                },
                completionHandler: { photoCaptureProcessor in
                    self.sessionQueue.async {
                        self.inProgressPhotoCaptureDelegates.removeValue(forKey: photoCaptureProcessor.requestPhotoSettings.uniqueID)
                    }
                }, photoProcessingHandler: { _ in  }
        )
        return photoCaptureProcessor
    }

    private func startAutomaticCapture() {
        dispatchPrecondition(condition: .onQueue(.main))
        precondition(triggerEveryTimer != nil)

        guard !triggerEveryTimer!.isRunning else {
            return
        }
        triggerEveryTimer!.start()

        isAutoCaptureActive = true
    }

    private func stopAutomaticCapture() {
        dispatchPrecondition(condition: .onQueue(.main))

        isAutoCaptureActive = false
        triggerEveryTimer?.stop()
    }

    private static func createNewCaptureFolder() throws -> CaptureFolderState {
        guard let newCaptureDir = CaptureFolderState.createCaptureDirectory() else {
            throw SetupError.failed(msg: "Cant create capture directory")
        }
        return CaptureFolderState(url: newCaptureDir)
    }

    private func requestAuthorizationIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
    }

    private func configureSession() {
        guard setupResult == .inProgress else {
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: getVideoDeviceForPhotogrammetry())

            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                setupResult = .configurationFailed
                return
            }
        } catch {
            print("Could not create video device input")
            setupResult = .configurationFailed
            return
        }

        DispatchQueue.main.async {
            self.isDepthDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            self.isHighQualityMode =
                    self.photoOutput.isHighResolutionCaptureEnabled
                    && self.photoOutput.maxPhotoQualityPrioritization == .quality
        }

        setupResult = .success
    }

    private func getVideoDeviceForPhotogrammetry() throws -> AVCaptureDevice {
        var defaultVideoDevice: AVCaptureDevice?

        if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            defaultVideoDevice = dualCameraDevice
        } else if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            defaultVideoDevice = dualWideCameraDevice
        } else if let backWideCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            defaultVideoDevice = backWideCameraDevice
        }

        guard let videoDevice = defaultVideoDevice else {
            print("Back video device unavailable.")
            throw SessionSetupError.configurationFailed
        }

        return videoDevice
    }
}
