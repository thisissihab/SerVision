import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum OCRService {

    // MARK: - Public OCR
    static func recognizeText(from image: UIImage,
                              completion: @escaping (Result<String, Error>) -> Void) {

        // Preprocess to fight textured metal + tiny text
        let inputImage = preprocessForOCR(image) ?? image

        guard let cgImage = inputImage.cgImage else {
            completion(.failure(NSError(domain: "OCR", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid image."
            ])))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                completion(.failure(error))
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines: [String] = observations.compactMap { obs in
                obs.topCandidates(1).first?.string
            }

            completion(.success(lines.joined(separator: "\n")))
        }

        // Better for small printed/etched text
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        // KEY: allow smaller text detection
        request.minimumTextHeight = 0.01   // try 0.01–0.03 if needed

        // Helpful hints (optional)
        request.customWords = ["Model", "Serial", "iPad", "EMC"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Preprocessing (Core Image)
    private static func preprocessForOCR(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        // 1) Grayscale + contrast
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 0.0
        colorControls.contrast = 1.5
        colorControls.brightness = 0.05

        // 2) Light denoise (keeps edges)
        let noiseReduction = CIFilter.noiseReduction()
        noiseReduction.inputImage = colorControls.outputImage
        noiseReduction.noiseLevel = 0.02
        noiseReduction.sharpness = 0.4

        // 3) Sharpen edges
        let unsharp = CIFilter.unsharpMask()
        unsharp.inputImage = noiseReduction.outputImage
        unsharp.radius = 2.5
        unsharp.intensity = 0.75

        guard let out = unsharp.outputImage,
              let outCG = context.createCGImage(out, from: out.extent) else { return nil }

        return UIImage(cgImage: outCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Extract Model + Serial
    static func extractModelAndSerial(from text: String) -> (model: String?, serial: String?) {
        let normalized = text
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "—", with: "-")

        // Primary patterns: "Model: XXX" / "Serial: YYY"
        let model1 = firstMatch(in: normalized, pattern: #"(?im)\bmodel\b\s*[:\-]?\s*([A-Z0-9,\-]+)"#)
        let serial1 = firstMatch(in: normalized, pattern: #"(?im)\bserial\b\s*[:\-]?\s*([A-Z0-9]+)"#)

        // Apple labels sometimes use "Model Axxxx"
        let model2 = firstMatch(in: normalized, pattern: #"(?im)\bmodel\b\s*(A\d{4})\b"#)
        // Serial is usually 10–12 alnum (varies)
        let serial2 = firstMatch(in: normalized, pattern: #"(?im)\b([A-Z0-9]{10,12})\b"#)

        // Choose best candidates
        let model = model1 ?? model2
        // serial2 is a fallback and can false-positive; only use if we didn't find serial1
        let serial = serial1 ?? serial2

        return (model, serial)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
            if match.numberOfRanges >= 2 {
                return ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if match.numberOfRanges == 1 {
                return ns.substring(with: match.range(at: 0)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        } catch {
            return nil
        }
    }
}
