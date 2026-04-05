import SwiftUI
import AVFoundation

// UIKit wrapper that shows the AVCaptureSession in a layer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        var session: AVCaptureSession? {
            didSet {
                guard let session else { return }
                previewLayer.session = session
            }
        }

        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
        }
    }
}

// MARK: - BarcodeScannerView

struct BarcodeScannerView: View {
    @StateObject private var vm = ScannerViewModel()
    /// Called when a barcode has been confirmed
    var onScanned: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            if vm.isSessionRunning || vm.captureSession.inputs.isEmpty {
                CameraPreviewView(session: vm.captureSession)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // Scanning reticle
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 260, height: 120)
                .shadow(color: .white.opacity(0.4), radius: 8)

            VStack {
                Spacer()

                switch vm.state {
                case .idle, .scanning:
                    Text("Point the camera at a barcode")
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding(.bottom, 40)

                case .found(let code):
                    VStack(spacing: 12) {
                        Text("Scanned: \(code)")
                            .font(.callout)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Button("Use this barcode") {
                            onScanned(code)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Scan again") {
                            vm.reset()
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.bottom, 40)

                case .error(let msg):
                    VStack(spacing: 8) {
                        Text(msg)
                            .foregroundColor(.red)
                        Button("Try again") { vm.reset() }
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 40)
                }

                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .padding(.bottom, 24)
                }
            }
        }
        .task {
            let granted = await vm.requestCameraAccess()
            if granted {
                vm.setupSession()
                vm.startSession()
            } else {
                vm.state = .error("Camera access denied. Please enable it in Settings.")
            }
        }
        .onDisappear {
            vm.stopSession()
        }
    }
}
