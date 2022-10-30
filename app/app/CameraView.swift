//
// Created by Emil Elton Nilsen on 30/10/2022.
//

import Foundation
import SwiftUI

struct CameraView: View {
    static let buttonBackingOpacity: CGFloat = 0.15

    @ObservedObject var model: CameraViewModel
    @State private var showInfo: Bool = false

    let aspectRatio: CGFloat = 4.0 / 3.0
    let previewCornerRadius: CGFloat = 15.0

    var body: some View {
        NavigationView {
            GeometryReader { geometryReader in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)

                    VStack {
                        Spacer()
                        CameraPreviewView(session: model.session)
                    }
                }
            }
        }
    }
}
