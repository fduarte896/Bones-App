import Foundation

/// Con qué intención se abre la hoja de registro.
struct RecordRequest: Identifiable {
    enum Target {
        case new
        case vaccine(Vaccine)
        case deworming(Deworming)
        case weight(WeightEntry)
    }

    let id = UUID()
    let pet: Pet
    var kind: RecordDraft.Kind
    var target: Target = .new
    /// Nombre de vacuna que ya viene elegido, al registrar desde su fila.
    var vaccineName: String?
    var dewormingKind: DewormingKind = .internal
    /// Al cumplir algo pendiente, la fecha propuesta es hoy y no la que estaba programada.
    var applyingToday = false

    var isEditing: Bool {
        if case .new = target { false } else { true }
    }

    static func fulfilling(_ item: CareItem, for pet: Pet) -> RecordRequest {
        switch item.kind {
        case .vaccine:
            if let pending = pet.vaccines.first(where: { $0.id == item.nextRecordID }) {
                return RecordRequest(pet: pet, kind: .vaccine, target: .vaccine(pending), applyingToday: true)
            }
            return RecordRequest(pet: pet, kind: .vaccine, vaccineName: item.title)
        case .deworming(let kind):
            if let pending = pet.dewormings.first(where: { $0.id == item.nextRecordID }) {
                return RecordRequest(pet: pet, kind: .deworming, target: .deworming(pending), applyingToday: true)
            }
            return RecordRequest(pet: pet, kind: .deworming, dewormingKind: kind)
        }
    }

    static func adding(to item: CareItem, for pet: Pet) -> RecordRequest {
        switch item.kind {
        case .vaccine:
            RecordRequest(pet: pet, kind: .vaccine, vaccineName: item.title)
        case .deworming(let kind):
            RecordRequest(pet: pet, kind: .deworming, dewormingKind: kind)
        }
    }
}
