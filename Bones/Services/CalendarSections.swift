import Foundation

// MARK: - Future event sections

enum EventSectionKind: Int, CaseIterable, Hashable {
    case today = 0
    case tomorrow
    case thisWeek
    case nextWeek
    case later

    var label: String {
        switch self {
        case .today:     return "Hoy"
        case .tomorrow:  return "Mañana"
        case .thisWeek:  return "Esta semana"
        case .nextWeek:  return "Próxima semana"
        case .later:     return "Más adelante"
        }
    }
}

// MARK: - Past event sections

enum PastSectionKind: Int, CaseIterable, Hashable {
    case yesterday = 0, lastWeek, lastMonth, earlier

    var label: String {
        switch self {
        case .yesterday:  return "Ayer"
        case .lastWeek:   return "Última semana"
        case .lastMonth:  return "Último mes"
        case .earlier:    return "Más antiguos"
        }
    }
}

// MARK: - Calendar classification helpers

extension Calendar {
    func sectionKind(for date: Date) -> EventSectionKind {
        if isDateInToday(date) { return .today }
        if isDateInTomorrow(date) { return .tomorrow }
        if isDate(date, equalTo: Date(), toGranularity: .weekOfYear) { return .thisWeek }
        if let nextWeek = self.date(byAdding: .weekOfYear, value: 1, to: Date()),
           isDate(date, equalTo: nextWeek, toGranularity: .weekOfYear) {
            return .nextWeek
        }
        return .later
    }

    func pastSectionKind(for date: Date) -> PastSectionKind {
        if isDateInYesterday(date) { return .yesterday }
        let now = Date.now
        if let weekAgo = self.date(byAdding: .day, value: -7, to: now), date >= weekAgo { return .lastWeek }
        if let monthAgo = self.date(byAdding: .month, value: -1, to: now), date >= monthAgo { return .lastMonth }
        return .earlier
    }
}
