import Foundation
import AVFoundation
import UIKit

// MARK: - Scanner state

enum ScannerState {
    case idle
    case scanning
    case found(String)
    case error(String)
}

// MARK: - ScannerViewModel

@MainActor
class ScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {

    @Published var state: ScannerState = .idle
    @Published var scannedCode: String? = nil
    @Published var isSessionRunning: Bool = false

    let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var sessionQueue = DispatchQueue(label: "com.library.scanner.session")

    // MARK: - Session lifecycle

    func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()

            guard
                let device = AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device),
                self.captureSession.canAddInput(input)
            else {
                self.captureSession.commitConfiguration()
                Task { @MainActor in
                    self.state = .error("Camera unavailable")
                }
                return
            }

            self.captureDevice = device
            self.captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard self.captureSession.canAddOutput(output) else {
                self.captureSession.commitConfiguration()
                return
            }
            self.captureSession.addOutput(output)
            self.metadataOutput = output

            // Barcode types we care about (ISBN barcodes are EAN-13)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            let supported = output.availableMetadataObjectTypes
            let desired: [AVMetadataObject.ObjectType] = [
                .ean13, .ean8, .upce, .code128, .qr
            ]
            output.metadataObjectTypes = desired.filter { supported.contains($0) }

            self.captureSession.commitConfiguration()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }

        Task { @MainActor in
            self.scannedCode = code
            self.state = .found(code)
            self.stopSession()
        }
    }

    // MARK: - Reset

    func reset() {
        scannedCode = nil
        state = .idle
        startSession()
    }
}
