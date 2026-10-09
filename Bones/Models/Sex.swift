import Foundation

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female, unknown

    var id: Self { self }

    var displayName: String {
        switch self {
        case .male:    "Macho"
        case .female:  "Hembra"
        case .unknown: "Sin especificar"
        }
    }
}
