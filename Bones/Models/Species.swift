import Foundation

enum Species: String, Codable, CaseIterable, Identifiable {
    case perro, gato

    var id: Self { self }

    var displayName: String {
        switch self {
        case .perro: "Perro"
        case .gato:  "Gato"
        }
    }

    var symbolName: String {
        switch self {
        case .perro: "dog.fill"
        case .gato:  "cat.fill"
        }
    }
}
