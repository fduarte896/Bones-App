import Foundation

/// Todo lo que la ficha necesita saber de una mascota, ya calculado.
struct PetHealthSummary {
    let vaccines: [CareItem]
    let internalDeworming: CareItem
    let externalDeworming: CareItem
    let weight: WeightSummary?

    init(pet: Pet, now: Date = .now, calendar: Calendar = .current) {
        self.init(vaccines: pet.vaccines, dewormings: pet.dewormings, weights: pet.weights,
                  now: now, calendar: calendar)
    }

    init(vaccines: [Vaccine], dewormings: [Deworming], weights: [WeightEntry],
         now: Date = .now, calendar: Calendar = .current) {
        self.vaccines = Dictionary(grouping: vaccines, by: \.careKind)
            .map { kind, records in
                let newest = records.max { $0.date < $1.date }
                return CareItem(kind: kind,
                                title: newest?.displayName ?? "Vacuna",
                                records: records,
                                detail: { $0.manufacturer?.nilIfBlank },
                                now: now, calendar: calendar)
            }
            .sorted {
                ($0.status.sortRank, $0.title.localizedLowercase) < ($1.status.sortRank, $1.title.localizedLowercase)
            }

        func deworming(_ kind: DewormingKind) -> CareItem {
            CareItem(kind: .deworming(kind),
                     title: kind.displayName,
                     records: dewormings.filter { $0.kind == kind },
                     detail: { $0.productName.nilIfBlank },
                     now: now, calendar: calendar)
        }
        internalDeworming = deworming(.internal)
        externalDeworming = deworming(.external)
        weight = WeightSummary(entries: weights)
    }

    var dewormings: [CareItem] { [internalDeworming, externalDeworming] }

    /// Lo vencido y lo que toca pronto, lo más urgente primero.
    var needingAttention: [CareItem] {
        (dewormings + vaccines)
            .filter(\.status.needsAttention)
            .sorted { ($0.nextDate ?? .distantFuture) < ($1.nextDate ?? .distantFuture) }
    }

    func item(for kind: CareKind) -> CareItem? {
        (dewormings + vaccines).first { $0.kind == kind }
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
