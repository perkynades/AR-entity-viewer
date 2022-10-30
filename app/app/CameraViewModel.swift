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
                && self.inprogressPhotoCaptureDelegates.count < 2
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
            guard triggereveryTimer != nil else { return }
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

        if motionmanager.isDeviceMotionAvailable {
            motionManager.StartDeviceMotionUpdates()
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
}































