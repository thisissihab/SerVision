import SwiftUI
import UIKit

struct ContentView: View {
    // Top: Asset ID input (manual + scanner)
    @State private var assetId: String = ""
    @State private var isShowingBarcodeScanner = false

    // OCR workflow
    @State private var isShowingCamera = false
    @State private var scannedText: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    // Editable fields (user can correct)
    @State private var modelText: String = ""
    @State private var serialText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("SerVision")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 10)

                // Asset ID row: TextField + Scan button
                Text("Please enter asset ID")
                    .font(.headline)

                HStack(spacing: 10) {
                    TextField("Asset ID", text: $assetId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        .padding(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        )

                    Button {
                        errorMessage = nil
                        isShowingBarcodeScanner = true
                    } label: {
                        Text("Scan")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Scan Text section label
                Text("Scan Text")
                    .font(.headline)

                // Camera area (same as before)
                Button {
                    errorMessage = nil
                    isShowingCamera = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .frame(height: 220)

                        VStack(spacing: 10) {
                            Image(systemName: "camera")
                                .font(.system(size: 40))
                            Text(isProcessing ? "Processing..." : "Click to Open Camera")
                                .font(.headline)
                        }
                    }
                }
                .disabled(isProcessing)

                // Editable Model / Serial
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Model")
                            .frame(width: 60, alignment: .leading)

                        TextField("Model", text: $modelText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .padding(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                    }

                    HStack {
                        Text("Serial")
                            .frame(width: 60, alignment: .leading)

                        TextField("Serial", text: $serialText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .padding(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .font(.subheadline)

                // Scanned data area
                Text("Scanned Data")
                    .font(.headline)

                TextEditor(text: $scannedText)
                    .padding(10)
                    .frame(minHeight: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                HStack {
                    Button("Clear") {
                        assetId = ""
                        scannedText = ""
                        modelText = ""
                        serialText = ""
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Copy") {
                        UIPasteboard.general.string = scannedText
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scannedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        // Barcode scanner sheet
        .sheet(isPresented: $isShowingBarcodeScanner) {
            BarcodeScannerView(
                supportedTypes: [.qr, .ean8, .ean13, .code128, .code39, .code93, .upce, .pdf417, .dataMatrix, .aztec]
            ) { result in
                switch result {
                case .success(let code):
                    // Put scan result into the editable Asset ID field
                    assetId = code
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                isShowingBarcodeScanner = false
            }
        }
        // Camera OCR sheet (existing)
        .sheet(isPresented: $isShowingCamera) {
            ImagePicker(sourceType: .camera) { image in
                runOCR(on: image)
            }
        }
    }

    private func runOCR(on image: UIImage) {
        isProcessing = true
        errorMessage = nil

        OCRService.recognizeText(from: image) { result in
            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success(let text):
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    scannedText = cleaned.isEmpty ? "(No text detected)" : cleaned

                    // Autofill model + serial, but user can edit afterwards
                    let fields = OCRService.extractModelAndSerial(from: scannedText)
                    modelText = fields.model ?? modelText
                    serialText = fields.serial ?? serialText

                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }
}
