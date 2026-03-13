//
//  BonesWidget.swift
//  BonesWidget
//
//  Created by Felipe Duarte on 8/03/26.
//

import WidgetKit
import SwiftUI

struct UpcomingEventsEntry: TimelineEntry {
    let date: Date
    let pet: WidgetPetSummary?
    let events: [WidgetEventSummary]
    let selectedType: EventTypeIntent
}

struct UpcomingEventsProvider: AppIntentTimelineProvider {
    typealias Intent = PetSelectionIntent
    typealias Entry = UpcomingEventsEntry

    func placeholder(in context: Context) -> UpcomingEventsEntry {
        UpcomingEventsEntry(date: .now,
                            pet: WidgetPetSummary(id: "preview", name: "Loki"),
                            events: [
                                WidgetEventSummary(id: "1", title: "Amoxicilina", type: "Medicamento", date: .now.addingTimeInterval(3600)),
                                WidgetEventSummary(id: "2", title: "Desparasitación", type: "Desparasitación", date: .now.addingTimeInterval(7200))
                            ],
                            selectedType: .all)
    }

    func snapshot(for configuration: PetSelectionIntent, in context: Context) async -> UpcomingEventsEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: PetSelectionIntent, in context: Context) async -> Timeline<UpcomingEventsEntry> {
        let entry = makeEntry(for: configuration)
        let nextRefresh = nextRefreshDate(from: entry)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func makeEntry(for configuration: PetSelectionIntent) -> UpcomingEventsEntry {
        let payload = WidgetStore.load()
        let selectedPetID = configuration.pet?.id ?? payload?.pets.first?.id
        let selectedPet = payload?.pets.first(where: { $0.id == selectedPetID })
        let allEvents = payload?.eventsByPetID[selectedPetID ?? ""] ?? []
        let events = filterEvents(allEvents, by: configuration.eventType)
        return UpcomingEventsEntry(date: .now,
                                   pet: selectedPet,
                                   events: events,
                                   selectedType: configuration.eventType)
    }

    private func filterEvents(_ events: [WidgetEventSummary], by type: EventTypeIntent) -> [WidgetEventSummary] {
        guard type != .all else { return events }
        return events.filter { event in
            matches(eventType: event.type, filter: type)
        }
    }

    private func matches(eventType: String, filter: EventTypeIntent) -> Bool {
        let normalized = eventType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch filter {
        case .all:
            return true
        case .medication:
            return normalized.contains("medicamento")
        case .vaccine:
            return normalized.contains("vacuna")
        case .deworming:
            return normalized.contains("desparas")
        case .grooming:
            return normalized.contains("peluquer")
        case .weight:
            return normalized.contains("peso")
        }
    }

    private func nextRefreshDate(from entry: UpcomingEventsEntry) -> Date {
        if let next = entry.events.first?.date {
            return max(next.addingTimeInterval(60), Date().addingTimeInterval(30 * 60))
        }
        return Date().addingTimeInterval(60 * 60)
    }
}

struct BonesUpcomingEventsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpcomingEventsEntry

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                largeBody
            case .systemMedium:
                mediumBody
            default:
                smallBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(widgetURL())
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let next = entry.events.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text(timeLabel(for: next.date))
                        .font(.system(size: 22, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(next.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        TagChip(text: next.type, tint: chipTint(for: next.type))
                        Text(shortDate(next.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                emptyState
            }
            Spacer(minLength: 0)
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                header
                if let next = entry.events.first {
                    Text(timeLabel(for: next.date))
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(next.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        TagChip(text: next.type, tint: chipTint(for: next.type))
                        Text(shortDate(next.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    emptyState
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Siguientes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(entry.events.dropFirst().prefix(2), id: \.id) { event in
                    HStack(spacing: 6) {
                        EventTitleChip(text: event.title, background: chipBackground(for: event.type))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(shortTime(event.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                if entry.events.count <= 1 {
                    Text("Sin más eventos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            largeHeader
            if let featured = entry.events.first {
                featuredCard(for: featured)
                Divider().opacity(0.25)
                largeList
            } else {
                emptyState
                Spacer(minLength: 0)
            }
        }
    }

    private var largeHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.pet?.name ?? "Mascota") · Próximos eventos")
                .font(.headline)
                .lineLimit(1)
            Text(headerSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var largeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Siguientes")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(entry.events.dropFirst().prefix(5), id: \.id) { event in
                LargeEventRow(title: event.title,
                              type: event.type,
                              timeText: shortTime(event.date),
                              tint: chipTint(for: event.type))
            }

            if entry.events.count <= 1 {
                Text("Sin más eventos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func featuredCard(for event: WidgetEventSummary) -> some View {
        let isOverdue = isOverdue(event.date)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(chipTint(for: event.type).opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: iconName(for: event.type))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(chipTint(for: event.type))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(timeLabel(for: event.date))
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isOverdue {
                    TagChip(text: "Vencida", tint: .red)
                }
            }

            HStack(spacing: 6) {
                TagChip(text: event.type, tint: chipTint(for: event.type))
                Text(shortDate(event.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(entry.pet?.name ?? "Mascota")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("• \(headerSuffix)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let next = entry.events.first, isOverdue(next.date) {
                TagChip(text: "Vencida", tint: .red)
                    .scaleEffect(0.85)
            }
        }
        .lineLimit(1)
    }

    private var headerSuffix: String {
        if entry.selectedType == .all {
            return "Próximo"
        }
        return selectedTypeLabel
    }

    private var headerSummary: String {
        let overdueCount = entry.events.filter { isOverdue($0.date) }.count
        let todayCount = entry.events.filter { Calendar.current.isDateInToday($0.date) }.count
        let todayLabel = todayCount > 0 ? "Hoy · \(todayCount) eventos" : "Próximos"
        if overdueCount > 0 {
            return "\(todayLabel) · \(overdueCount) vencidos"
        }
        return todayLabel
    }

    private var selectedTypeLabel: String {
        switch entry.selectedType {
        case .all:
            return "Todos"
        case .medication:
            return "Meds"
        case .vaccine:
            return "Vacunas"
        case .deworming:
            return "Despar."
        case .grooming:
            return "Peluquería"
        case .weight:
            return "Peso"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sin próximos")
                .font(.headline)
            Text("Agrega eventos para verlos aquí")
                .font(.caption)
                .foregroundStyle(.secondary)
            TagChip(text: "Agregar evento", tint: .blue)
        }
    }

    private func widgetURL() -> URL? {
        guard let pet = entry.pet else { return URL(string: "bones://events") }
        var components = URLComponents()
        components.scheme = "bones"
        components.host = "events"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "petId", value: pet.id),
            URLQueryItem(name: "petName", value: pet.name)
        ]
        if entry.events.isEmpty {
            items.append(URLQueryItem(name: "action", value: "add"))
        }
        components.queryItems = items
        return components.url
    }

    private func timeLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return formattedTime(date)
        }
        if cal.isDateInTomorrow(date) {
            return "Mañana"
        }
        return formattedShortDate(date)
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Hoy"
        }
        if cal.isDateInTomorrow(date) {
            return "Mañana"
        }
        return formattedShortDate(date)
    }

    private func shortTime(_ date: Date) -> String {
        formattedTime(date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date()
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .current
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func chipTint(for type: String) -> Color {
        switch type.lowercased() {
        case "medicamento", "medicamentos":
            return .blue
        case "vacuna", "vacunas":
            return .green
        case "desparasitación", "desparasitacion":
            return .orange
        case "peluquería", "peluqueria":
            return .teal
        case "registro de peso", "peso":
            return .gray
        default:
            return .secondary
        }
    }

    private func chipBackground(for type: String) -> Color {
        chipTint(for: type).opacity(0.12)
    }

    private func iconName(for type: String) -> String {
        switch type.lowercased() {
        case "medicamento", "medicamentos":
            return "pills.fill"
        case "vacuna", "vacunas":
            return "syringe"
        case "desparasitación", "desparasitacion":
            return "ladybug.fill"
        case "peluquería", "peluqueria":
            return "scissors"
        case "registro de peso", "peso":
            return "scalemass"
        default:
            return "bell"
        }
    }
}

private struct TagChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(tint)
    }
}

private struct EventTitleChip: View {
    let text: String
    let background: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Capsule().fill(background))
            .foregroundStyle(.primary)
    }
}

private struct LargeEventRow: View {
    let title: String
    let type: String
    let timeText: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(timeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 54, alignment: .leading)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            TagChip(text: type, tint: tint)
                .scaleEffect(0.9)
        }
    }
}

struct BonesUpcomingEventsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BonesUpcomingEventsWidget",
                               intent: PetSelectionIntent.self,
                               provider: UpcomingEventsProvider()) { entry in
            BonesUpcomingEventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Próximos de tu mascota")
        .description("Muestra los próximos eventos de una mascota.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [
                            WidgetEventSummary(id: "1", title: "Amoxicilina", type: "Medicamento", date: .now.addingTimeInterval(3600)),
                            WidgetEventSummary(id: "2", title: "Desparasitación", type: "Desparasitación", date: .now.addingTimeInterval(7200))
                        ],
                        selectedType: .all)
}

#Preview("Small vacío", as: .systemSmall) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [],
                        selectedType: .all)
}

#Preview("Small Medicamentos", as: .systemSmall) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [
                            WidgetEventSummary(id: "1", title: "Amoxicilina", type: "Medicamento", date: .now.addingTimeInterval(3600))
                        ],
                        selectedType: .medication)
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [],
                        selectedType: .medication)
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [
                            WidgetEventSummary(id: "1", title: "Amoxicilina", type: "Medicamento", date: .now.addingTimeInterval(-7200))
                        ],
                        selectedType: .medication)
}
#Preview(as: .systemMedium) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Kira"),
                        events: [
                            WidgetEventSummary(id: "1", title: "Vacuna rabia", type: "Vacuna", date: .now.addingTimeInterval(3600)),
                            WidgetEventSummary(id: "2", title: "Baño", type: "Peluquería", date: .now.addingTimeInterval(7200)),
                            WidgetEventSummary(id: "3", title: "Desparasitación", type: "Desparasitación", date: .now.addingTimeInterval(10800))
                        ],
                        selectedType: .all)
}

#Preview("Medium vacío", as: .systemMedium) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Kira"),
                        events: [],
                        selectedType: .all)
}

#Preview("Large demo", as: .systemLarge) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [
                            WidgetEventSummary(id: "1", title: "Amoxicilina", type: "Medicamento", date: .now.addingTimeInterval(-3600)),
                            WidgetEventSummary(id: "2", title: "Desparasitación", type: "Desparasitación", date: .now.addingTimeInterval(7200)),
                            WidgetEventSummary(id: "3", title: "Baño y corte", type: "Peluquería", date: .now.addingTimeInterval(10800)),
                            WidgetEventSummary(id: "4", title: "Vacuna rabia", type: "Vacuna", date: .now.addingTimeInterval(86400)),
                            WidgetEventSummary(id: "5", title: "Control de peso", type: "Registro de peso", date: .now.addingTimeInterval(172800)),
                            WidgetEventSummary(id: "6", title: "Moquillo (dosis 2/3)", type: "Vacuna", date: .now.addingTimeInterval(259200))
                        ],
                        selectedType: .all)
}
