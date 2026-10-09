import SwiftUI

// MARK: - Hex color initializer
extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Bones color tokens
extension Color {
    static let bonesBg        = Color(hex: 0xF6F6F4)
    static let bonesPanel     = Color.white
    static let bonesInk       = Color(hex: 0x13161A)
    static let bonesInkSoft   = Color(hex: 0x5C636E)
    static let bonesInkFaint  = Color(hex: 0x9CA3AF)
    static let bonesRule      = Color(hex: 0xECEDEF)
    static let bonesRuleSoft  = Color(hex: 0xF4F4F2)
    static let bonesAccent    = Color(hex: 0x0E5C4F)

    static let bonesOk        = Color(hex: 0x3D8A5A)
    static let bonesSoon      = Color(hex: 0xC99A2C)
    static let bonesOverdue   = Color(hex: 0xB0413E)

    static let bonesVaccine   = Color(hex: 0x3D8A5A)
    static let bonesDeworming = Color(hex: 0xC99A2C)
    static let bonesWeight    = Color(hex: 0x3C4A6B)
}

// MARK: - PetTone
struct PetTone {
    let ink: Color
    let soft: Color
    let hue: Color

    static let forest     = PetTone(ink: Color(hex: 0x3D5A4A), soft: Color(hex: 0xE8EDE6), hue: Color(hex: 0x7A9988))
    static let terracotta = PetTone(ink: Color(hex: 0x8B4A2E), soft: Color(hex: 0xF2E6DC), hue: Color(hex: 0xC57A52))
    static let slate      = PetTone(ink: Color(hex: 0x3C4A6B), soft: Color(hex: 0xE4E8EF), hue: Color(hex: 0x6E84A8))
    static let ochre      = PetTone(ink: Color(hex: 0x8A6E1F), soft: Color(hex: 0xF1ECD8), hue: Color(hex: 0xBFA13E))
    static let plum       = PetTone(ink: Color(hex: 0x5C3D6E), soft: Color(hex: 0xECE3F1), hue: Color(hex: 0x9272A6))
    static let caramel    = PetTone(ink: Color(hex: 0x7A5230), soft: Color(hex: 0xF1E6D8), hue: Color(hex: 0xB8895A))

    static let all: [PetTone] = [.forest, .terracotta, .slate, .ochre, .plum, .caramel]
}

// MARK: - HealthStatus
enum HealthStatus: Equatable {
    case ok, soon, overdue

    var color: Color {
        switch self {
        case .ok:      return .bonesOk
        case .soon:    return .bonesSoon
        case .overdue: return .bonesOverdue
        }
    }
}

// MARK: - WeightTrend
enum WeightTrend { case up, down, flat }

// MARK: - Bones date helpers
private let _bonesShortDateFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es")
    f.setLocalizedDateFormatFromTemplate("dMMM")
    return f
}()

func bonesShortDate(_ date: Date) -> String {
    _bonesShortDateFmt.string(from: date)
}

func bonesRelativeLabel(for date: Date) -> String {
    let cal = Calendar.current
    let now = Date()
    if cal.isDateInToday(date)     { return "hoy" }
    if cal.isDateInTomorrow(date)  { return "mañana" }
    if cal.isDateInYesterday(date) { return "ayer" }
    return esRelativeFormatter.localizedString(for: date, relativeTo: now)
}

// MARK: - Pet design helpers
extension Pet {
    var tone: PetTone {
        PetTone.all[abs(id.hashValue) % PetTone.all.count]
    }

    var healthStatus: HealthStatus {
        let now = Date()
        let week: TimeInterval = 7 * 24 * 3600
        if vaccines.contains(where:   { !$0.isCompleted && $0.date < now }) ||
           dewormings.contains(where:  { !$0.isCompleted && $0.date < now }) {
            return .overdue
        }
        let nextVacc = vaccines.filter   { !$0.isCompleted && $0.date >= now }.map(\.date).min()
        let nextDew  = dewormings.filter  { !$0.isCompleted && $0.date >= now }.map(\.date).min()
        if let next = [nextVacc, nextDew].compactMap({ $0 }).min(),
           next.timeIntervalSince(now) < week { return .soon }
        return .ok
    }

    var healthStatusLabel: String {
        let now = Date()
        switch healthStatus {
        case .overdue: return "Vencido"
        case .soon:
            let nextVacc = vaccines.filter   { !$0.isCompleted && $0.date >= now }.map(\.date).min()
            let nextDew  = dewormings.filter  { !$0.isCompleted && $0.date >= now }.map(\.date).min()
            if let next = [nextVacc, nextDew].compactMap({ $0 }).min() {
                return bonesRelativeLabel(for: next)
            }
            return "Próximo"
        case .ok: return "Al día"
        }
    }
}
