import Foundation

// MARK: - Shared age formatting

func ageString(for birth: Date?) -> String? {
    guard let birth else { return nil }
    let comp = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
    let y = comp.year ?? 0, m = comp.month ?? 0
    switch (y, m) {
    case (0, 0): return "Recién nacido"
    case (0, _): return "\(m) mes\(m > 1 ? "es" : "")"
    default:     return "\(y) año\(y > 1 ? "s" : "") \(m) m"
    }
}

// MARK: - Sex localization

extension Sex {
    var displayName: String {
        switch self {
        case .male:    return "Macho"
        case .female:  return "Hembra"
        case .unknown: return "Desconocido"
        }
    }
}

// MARK: - Spanish date formatters

let esRelativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "es")
    f.unitsStyle = .full
    return f
}()

let esDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es")
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

let esDateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es")
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

func formatDate(_ date: Date) -> String { esDateFormatter.string(from: date) }
func formatDateTime(_ date: Date) -> String { esDateTimeFormatter.string(from: date) }
