import Foundation

/// Una fila del historial, sea vacuna o desparasitación.
struct HistoryEntry: Identifiable {
    let id: UUID
    let date: Date
    let isApplied: Bool
    let name: String
    let detail: String?
    let notes: String?
    let hasPhoto: Bool
    let target: RecordRequest.Target

    init(_ vaccine: Vaccine) {
        id = vaccine.id
        date = vaccine.date
        isApplied = vaccine.isCompleted
        name = vaccine.displayName
        detail = vaccine.manufacturer?.nilIfBlank
        notes = vaccine.notes?.nilIfBlank
        hasPhoto = vaccine.prescriptionImageData != nil
        target = .vaccine(vaccine)
    }

    init(_ deworming: Deworming) {
        id = deworming.id
        date = deworming.date
        isApplied = deworming.isCompleted
        name = deworming.displayName
        detail = nil
        notes = deworming.notes?.nilIfBlank
        hasPhoto = deworming.prescriptionImageData != nil
        target = .deworming(deworming)
    }

    static func entries(for kind: CareKind, pet: Pet) -> [HistoryEntry] {
        switch kind {
        case .vaccine:
            pet.vaccines.filter { $0.careKind == kind }.map(HistoryEntry.init)
        case .deworming(let dewormingKind):
            pet.dewormings.filter { $0.kind == dewormingKind }.map(HistoryEntry.init)
        }
    }
}
