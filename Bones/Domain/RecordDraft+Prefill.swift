import Foundation

/// Cómo llega rellena la hoja de registro: con lo que ya se sabe de la mascota.
extension RecordDraft {
    /// Un registro nuevo, con lo último que se usó como punto de partida.
    static func new(kind: Kind, vaccineName: String? = nil, dewormingKind: DewormingKind = .internal,
                    date: Date = .now, summary: PetHealthSummary) -> RecordDraft {
        var draft = RecordDraft(kind: kind, date: date)
        switch kind {
        case .vaccine:
            draft.useVaccine(named: vaccineName ?? "", summary: summary)
        case .deworming:
            draft.useDewormingKind(dewormingKind, summary: summary)
        case .weight:
            draft.weightKg = summary.weight?.latestKg
        }
        return draft
    }

    /// Elige una vacuna y propone la repetición que se usó la última vez.
    mutating func useVaccine(named name: String, summary: PetHealthSummary) {
        self.name = name
        let known = summary.item(for: .vaccine(key: CareKind.vaccineKey(for: name)))
        repeatRule = known?.repeatRule ?? .yearly
    }

    /// Cambia entre interna y externa, proponiendo el último producto de ese tipo.
    mutating func useDewormingKind(_ kind: DewormingKind, summary: PetHealthSummary) {
        let known = summary.item(for: .deworming(kind))
        dewormingKind = kind
        name = known?.lastDetail ?? ""
        repeatRule = known?.repeatRule ?? kind.defaultRepeat
    }

    init(vaccine: Vaccine, applyingToday: Bool, now: Date = .now) {
        self.init(kind: .vaccine,
                  name: vaccine.displayName,
                  date: applyingToday ? now : vaccine.date,
                  repeatRule: vaccine.repeatRule ?? (applyingToday ? .yearly : nil),
                  manufacturer: vaccine.manufacturer ?? "",
                  notes: vaccine.notes ?? "",
                  photoData: vaccine.prescriptionImageData)
    }

    init(deworming: Deworming, applyingToday: Bool, now: Date = .now) {
        self.init(kind: .deworming,
                  name: deworming.productName,
                  dewormingKind: deworming.kind,
                  date: applyingToday ? now : deworming.date,
                  repeatRule: deworming.repeatRule ?? (applyingToday ? deworming.kind.defaultRepeat : nil),
                  notes: deworming.notes ?? "",
                  photoData: deworming.prescriptionImageData)
    }

    init(weight: WeightEntry) {
        self.init(kind: .weight, date: weight.date, notes: weight.notes ?? "", weightKg: weight.weightKg)
    }

    @MainActor
    init(request: RecordRequest, now: Date = .now) {
        switch request.target {
        case .new:
            self = .new(kind: request.kind,
                        vaccineName: request.vaccineName,
                        dewormingKind: request.dewormingKind,
                        date: now,
                        summary: PetHealthSummary(pet: request.pet, now: now))
        case .vaccine(let vaccine):
            self.init(vaccine: vaccine, applyingToday: request.applyingToday, now: now)
        case .deworming(let deworming):
            self.init(deworming: deworming, applyingToday: request.applyingToday, now: now)
        case .weight(let weight):
            self.init(weight: weight)
        }
    }
}
