import Foundation

enum DewormingKind: String, CaseIterable, Identifiable {
    /// Parásitos intestinales: pastillas, jarabes, pastas.
    case `internal`
    /// Pulgas y garrapatas: pipetas, collares, masticables.
    case external

    var id: Self { self }

    var displayName: String {
        switch self {
        case .internal: "Interna"
        case .external: "Externa"
        }
    }

    var longName: String {
        switch self {
        case .internal: "Desparasitación interna"
        case .external: "Desparasitación externa"
        }
    }

    var hint: String {
        switch self {
        case .internal: "Parásitos intestinales"
        case .external: "Pulgas y garrapatas"
        }
    }

    var symbolName: String {
        switch self {
        case .internal: "pills.fill"
        case .external: "ladybug.fill"
        }
    }

    var defaultRepeat: RepeatRule {
        switch self {
        case .internal: RepeatRule(value: 3, unit: .months)
        case .external: RepeatRule(value: 1, unit: .months)
        }
    }
}
