import Foundation
import Vision
import UIKit

final class OCRService: Sendable {
    enum OCRError: Error { case imageDecode, failed }
    
    func recognizeText(from imageData: Data) async throws -> String {
        guard let ui = UIImage(data: imageData) else { throw OCRError.imageDecode }
        return try await recognizeText(from: ui)
    }
    
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw OCRError.imageDecode }
        // Offload CPU-intensive Vision work off the caller's actor
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es-ES", "es", "en-US", "en"]
            
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            
            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }
}
