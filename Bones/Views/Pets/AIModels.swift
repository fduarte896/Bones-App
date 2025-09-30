import Foundation

enum ProposedEventKind: String, Codable, CaseIterable, Sendable {
    case medication
    case vaccine
    case deworming
    case grooming
    case weight
}

struct ProposedEvent: Identifiable, Codable, Sendable {
    let id = UUID()
    let kind: ProposedEventKind
    let baseName: String            // nombre sin “(dosis X/Y)”
    let fullName: String            // puede incluir “(dosis X/Y)”
    let date: Date
    var dosage: String?             // ej. “250 mg”
    var frequency: String?          // ej. “cada 8 h”
    var notes: String?
    var manufacturer: String?       // vacunas
}

struct PrescriptionExtractionResult: Codable, Sendable {
    var kind: ProposedEventKind?    // si puede inferirse
    var baseName: String?
    var fullName: String?
    var dosage: String?
    var frequency: String?
    var date: Date?
    var manufacturer: String?
    var notes: String?
    var confidence: Double          // 0..1, heurístico
}

struct QuickAddParseResult: Codable, Sendable {
    var events: [ProposedEvent]
    var warnings: [String] = []
}
