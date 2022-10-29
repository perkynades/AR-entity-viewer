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
}
