import SwiftUI

extension CareStatus {
    var tint: Color {
        switch self {
        case .overdue:                 .red
        case .dueSoon:                 .orange
        case .upToDate:                .green
        case .noNextDate, .unrecorded: .secondary
        }
    }

    /// Cada estado tiene su propio símbolo, para no depender solo del color.
    var symbolName: String {
        switch self {
        case .overdue:                 "exclamationmark.circle.fill"
        case .dueSoon:                 "clock.fill"
        case .upToDate:                "checkmark.circle.fill"
        case .noNextDate, .unrecorded: "circle.dashed"
        }
    }

    /// Texto corto para el borde de una fila.
    var badgeText: String? {
        switch self {
        case .overdue:                 "Vencida"
        case .dueSoon(0):              "Hoy"
        case .dueSoon(1):              "Mañana"
        case .dueSoon(let days):       "En \(BonesFormat.span(days: days))"
        case .upToDate:                "Al día"
        case .noNextDate, .unrecorded: nil
        }
    }
}
