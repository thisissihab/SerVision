//
//  BarcodeScannerView.swift
//  SerVision
//
//  Created by Md Sihab Uddin on 23/2/2026.
//

import SwiftUI
import AVFoundation
import UIKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    enum ScanError: LocalizedError {
        case cameraUnavailable
        case noBarcodeFound

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera is not available."
            case .noBarcodeFound: return "No barcode detected."
            }
        }
    }

    let supportedTypes: [AVMetadataObject.ObjectType]
    let completion: (Result<String, Error>) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.supportedTypes = supportedTypes
        vc.onResult = completion
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var supportedTypes: [AVMetadataObject.ObjectType] = [.qr]
        var onResult: ((Result<String, Error>) -> Void)?

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureCamera()
            addOverlay()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }

        private func configureCamera() {
            guard let device = AVCaptureDevice.default(for: .video) else {
                onResult?(.failure(ScanError.cameraUnavailable))
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }

                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) { session.addOutput(output) }

                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = supportedTypes

                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.videoGravity = .resizeAspectFill
                preview.frame = view.layer.bounds
                view.layer.insertSublayer(preview, at: 0)
                previewLayer = preview

            } catch {
                onResult?(.failure(error))
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
        }

        private func addOverlay() {
            // Simple center guide box
            let guide = UIView()
            guide.translatesAutoresizingMaskIntoConstraints = false
            guide.layer.borderWidth = 2
            guide.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
            guide.layer.cornerRadius = 16
            guide.backgroundColor = UIColor.clear

            view.addSubview(guide)
            NSLayoutConstraint.activate([
                guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                guide.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
                guide.heightAnchor.constraint(equalTo: guide.widthAnchor, multiplier: 0.45)
            ])

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "Align barcode inside the box"
            label.textColor = UIColor.white.withAlphaComponent(0.9)
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 15, weight: .semibold)

            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                label.topAnchor.constraint(equalTo: guide.bottomAnchor, constant: 18)
            ])
        }

        // MARK: - AVCaptureMetadataOutputObjectsDelegate
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue,
                  !value.isEmpty else { return }

            // Stop after first detection
            session.stopRunning()
            onResult?(.success(value))
        }
    }
}
