import Foundation

/// Nombres que se proponen al registrar, para escribir menos.
enum ProductCatalog {
    static func defaultVaccines(for species: Species) -> [String] {
        switch species {
        case .perro: ["Antirrábica", "Polivalente", "Leptospirosis", "Tos de las perreras"]
        case .gato:  ["Antirrábica", "Triple felina", "Leucemia felina"]
        }
    }

    static func defaultProducts(for kind: DewormingKind) -> [String] {
        switch kind {
        case .internal: ["Drontal", "Milbemax", "Panacur"]
        case .external: ["Bravecto", "NexGard", "Simparica", "Frontline"]
        }
    }

    /// Lo que ya se ha usado, lo más reciente primero, seguido de los nombres comunes.
    static func suggestions(used: [(name: String, date: Date)], defaults: [String], limit: Int = 6) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        let recent = used.sorted { $0.date > $1.date }.map(\.name)
        for name in recent + defaults {
            let key = CareKind.vaccineKey(for: name)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(DoseLabel.split(name).base)
            if result.count == limit { break }
        }
        return result
    }

    /// Adivina si un producto de versiones anteriores era contra pulgas y garrapatas.
    static func guessKind(forProduct name: String) -> DewormingKind {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: BonesFormat.locale)
        return externalHints.contains { folded.contains($0) } ? .external : .internal
    }

    private static let externalHints = [
        "bravecto", "nexgard", "simparica", "frontline", "advantix", "advantage", "seresto",
        "revolution", "credelio", "effipro", "fipronil", "vectra", "comfortis", "capstar",
        "pipeta", "collar", "pulga", "garrapata", "antipulgas"
    ]
}
