//
// Created by Emil Elton Nilsen on 30/10/2022.
//

import AVFoundation
import SwiftUI
import UIKit
import os

struct CameraPreviewView: UIViewRepresentable {
    let previewCornerRadius: CGFloat = 50

    class PreviewView: UIView {
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
            }
            return layer
        }

        var session: AVCaptureSession? {
            get { videoPreviewLayer.session }
            set { videoPreviewLayer.session = newValue }
        }
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }

    let session: AVCaptureSession

    init (session: AVCaptureSession) {
        self.session = session
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()

        view.videoPreviewLayer.session = session
        view.backgroundColor = .black
        view.videoPreviewLayer.cornerRadius = 0
        view.videoPreviewLayer.connection?.videoOrientation = .portrait

        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) { }
}
