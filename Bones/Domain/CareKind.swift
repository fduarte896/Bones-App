import Foundation

/// Identifica una cosa a la que se le hace seguimiento: una vacuna concreta
/// o uno de los dos tipos de desparasitación.
enum CareKind: Hashable {
    case vaccine(key: String)
    case deworming(DewormingKind)

    /// Clave con la que se agrupan las aplicaciones de una misma vacuna:
    /// sin el sufijo de dosis, sin tildes ni mayúsculas.
    static func vaccineKey(for name: String) -> String {
        DoseLabel.split(name).base
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: BonesFormat.locale)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

extension Vaccine {
    var displayName: String { DoseLabel.split(vaccineName).base }
    var careKind: CareKind { .vaccine(key: CareKind.vaccineKey(for: vaccineName)) }
}

extension Deworming {
    var displayName: String { productName.isEmpty ? "Sin especificar" : productName }
    var careKind: CareKind { .deworming(kind) }
}
