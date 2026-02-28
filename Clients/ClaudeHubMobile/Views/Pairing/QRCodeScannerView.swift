import AVFoundation
import SwiftUI
import UIKit

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCodeScanned: (String) -> Void
        private let onFailure: (String) -> Void
        private var hasScannedCode = false

        init(
            onCodeScanned: @escaping (String) -> Void,
            onFailure: @escaping (String) -> Void
        ) {
            self.onCodeScanned = onCodeScanned
            self.onFailure = onFailure
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScannedCode,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let payload = object.stringValue
            else { return }

            hasScannedCode = true
            onCodeScanned(payload)
        }

        func reportFailure(_ message: String) {
            guard !hasScannedCode else { return }
            onFailure(message)
        }
    }
}

final class ScannerViewController: UIViewController {
    var coordinator: QRCodeScannerView.Coordinator?

    private let captureSession = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.session = captureSession
        view.layer.addSublayer(previewLayer)

        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAuthorizedSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureAuthorizedSession()
                    } else {
                        self.coordinator?.reportFailure("Camera access denied.")
                    }
                }
            }

        case .denied, .restricted:
            coordinator?.reportFailure("Camera access denied.")

        @unknown default:
            coordinator?.reportFailure("Camera access is unavailable.")
        }
    }

    private func configureAuthorizedSession() {
        guard captureSession.inputs.isEmpty else { return }
        guard let camera = AVCaptureDevice.default(for: .video) else {
            coordinator?.reportFailure("No camera available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(input) else {
                coordinator?.reportFailure("Unable to access the camera input.")
                return
            }
            captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(output) else {
                coordinator?.reportFailure("Unable to scan QR codes on this device.")
                return
            }
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]

            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        } catch {
            coordinator?.reportFailure("Unable to configure the camera: \(error.localizedDescription)")
        }
    }
}
