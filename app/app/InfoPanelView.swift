//
// Created by Emil Elton Nilsen on 30/10/2022.
//

import Combine
import SwiftUI

struct InfoPanelView: View {
    @ObservedObject var model: CameraViewModel

    var body: some View {
        VStack {
            HStack {
                CameraStatusLabel(
                        enabled: model.isCameraAvailable,
                        qualityMode: model.isHighQualityMode
                )
                        .alignmentGuide(.leading, computeValue: { dimension in
                            dimension.width
                        })
                Spacer()
                GravityStatusLabel(enabled: model.isMotionDataEnabled)
                        .alignmentGuide(
                                HorizontalAlignment.center,
                                computeValue: { dimension in
                                    dimension.width
                                })
                Spacer()
                DepthStatusLabel(enabled: model.isDepthDataEnabled)
                        .alignmentGuide(
                                .trailing, computeValue: { dimension in
                            dimension.width
                        })
            }
            Spacer(minLength: 18)
            HStack {
                Text("Captures: \(model.captureFolderState!.captures.count)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                Spacer()
                Label(title: {
                    Text("Recommended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                },
                        icon: {
                            ZStack {
                                Capsule()
                                        .foregroundColor(CaptureCountProgressBar.unfilledProgressColor)
                                        .frame(width: 20, height: 7, alignment: .leading)
                                Capsule()
                                        .foregroundColor(CaptureCountProgressBar.recommendedZoneColor)
                                frame(width: 20, height: 7, alignment: .leading)
                            }
                        })
            }
            CaptureCountProgressBar(model: model)
        }.font(.caption).transition(.move(edge: .top))
    }
}

struct CaptureCountProgressBar: View {
    @ObservedObject var model: CameraViewModel

    let height: CGFloat = 5
    let recommendedZoneHeight: CGFloat = 10

    static let recommendedZoneColor = Color(red: 0, green: 1, blue: 0, opacity: 0.5)
    static let unfilledProgressColor = Color(red: 1, green: 1, blue: 1, opacity: 0.5)

    var body: some View {
        GeometryReader { geometryReader in
            ZStack(alignment: .leading) {
                Capsule()
                        .frame(width: geometryReader.size.width, height: height, alignment: .leading)
                        .foregroundColor(CaptureCountProgressBar.unfilledProgressColor)
                Capsule()
                        .frame(
                                width: CGFloat(Double(model.captureFolderState!.captures.count)
                                        / Double(CameraViewModel.maxPhotosAllowed)
                                        * Double(geometryReader.size.width)),
                                height: height,
                                alignment: .leading
                        )
                        .foregroundColor(Color.white)
                Capsule()
                        .frame(width: CGFloat(Double(
                                CameraViewModel.recommendedMaxPhotos - CameraViewModel.recommendedMinPhotos)
                                / Double(CameraViewModel.maxPhotosAllowed))
                                * geometryReader.size.width,
                                height: recommendedZoneHeight, alignment: .leading
                        )
                        .foregroundColor(CaptureCountProgressBar.recommendedZoneColor)
                        .offset(x: CGFloat(
                                Double(CameraViewModel.recommendedMinPhotos)
                                / Double(CameraViewModel.maxPhotosAllowed))
                                * geometryReader.size.width,
                                y: 0
                        )
            }
        }
    }
}

struct CameraStatusLabel: View {
    var enabled: Bool = true
    var qualityMode: Bool = true

    var body: some View {
        if enabled && qualityMode {
            Image(systemName: "camera").foregroundColor(Color.green)
            Text("High Quality").foregroundColor(.secondary).font(.caption)
        } else if enabled {
            Image(systemName: "exclamationmark.circle").foregroundColor(Color.yellow)
            Text("Low Quality").foregroundColor(.secondary).font(.caption)
        } else {
            Image(systemName: "xmark.circle").foregroundColor(Color.red)
            Text("Unavailable").foregroundColor(.secondary).font(.caption)
        }
    }
}

struct GravityStatusLabel: View {
    var enabled: Bool = true

    var body: some View {
        if enabled {
            Image(systemName: "arrow.down.to.line.alt").foregroundColor(Color.green)
        } else {
            Image(systemName: "xmark.circle").foregroundColor(Color.red)
        }
        Text("Gravity Info").font(.caption).foregroundColor(Color.secondary)
    }
}

struct DepthStatusLabel: View {
    var enabled: Bool = true

    var body: some View {
        if enabled {
            Image(systemName: "square.3.stack.3d.top.fill").foregroundColor(Color.green)
        } else {
            Image(systemName: "xmark.circle").foregroundColor(Color.red)
        }
        Text("Depth").font(.caption).foregroundColor(.secondary)
    }
}

struct SystemStatusIcon: View {
    @ObservedObject var model: CameraViewModel

    init(model: CameraViewModel) {
        self.model = model
    }

    var body: some View {
        if !model.isCameraAvailable {
            Image(systemName: "xmark.circle").foregroundColor(Color.red)
        } else if model.isMotionDataEnabled && model.isDepthDataEnabled {
            Image(systemName: "checkmark.circle").foregroundColor(Color.green)
        } else {
            Image(systemName: "exclamationmark.circle").foregroundColor(Color.yellow)
        }
    }
}
