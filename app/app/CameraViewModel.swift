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
}
