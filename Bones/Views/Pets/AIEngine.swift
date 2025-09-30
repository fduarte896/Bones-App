import Foundation
import SwiftData
import UIKit

@MainActor
final class AIEngine {
    static let shared = AIEngine()
    
    private let ocr = OCRService()
    private let nlp = NLPParser()
    private let recommender = ScheduleRecommender()
    private let weightDetector = WeightAnomalyDetector()
    
    private init() {}
    
    // 1) OCR + NLP de receta/foto
    func extractPrescription(from imageData: Data, now: Date = Date()) async -> PrescriptionExtractionResult {
        do {
            let text = try await ocr.recognizeText(from: imageData)
            return nlp.extractFromOCR(text, now: now)
        } catch {
            return PrescriptionExtractionResult(kind: nil, baseName: nil, fullName: nil, dosage: nil, frequency: nil, date: nil, manufacturer: nil, notes: nil, confidence: 0.0)
        }
    }
    
    // 2) Quick Add de lenguaje natural
    func parseQuickAdd(text: String, defaultKind: ProposedEventKind? = nil, reference: Date = Date()) -> QuickAddParseResult {
        nlp.parseQuickAdd(text, defaultKind: defaultKind, reference: reference)
    }
    
    // 3) Recomendación de series
    func recommendSeries(for kind: ProposedEventKind, baseName: String, start: Date, dosage: String? = nil, hoursInterval: Int? = nil, totalDoses: Int? = nil) -> [ProposedEvent] {
        switch kind {
        case .vaccine:
            return recommender.recommendVaccineSeries(baseName: baseName, start: start)
        case .medication:
            return recommender.recommendMedicationSeries(baseName: baseName, start: start, hoursInterval: hoursInterval, totalDoses: totalDoses ?? 3, dosage: dosage)
        case .deworming, .grooming, .weight:
            // MVP: sin reglas específicas
            return [ProposedEvent(kind: kind, baseName: baseName, fullName: baseName, date: start, dosage: dosage, frequency: nil, notes: nil, manufacturer: nil)]
        }
    }
    
    // 4) Detección de anomalía de peso
    func analyzeWeight(for petID: UUID, context: ModelContext) -> WeightAnomalyResult? {
        weightDetector.analyze(petID: petID, context: context)
    }
}
