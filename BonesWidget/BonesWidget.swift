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
                            ])
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
        let events = payload?.eventsByPetID[selectedPetID ?? ""] ?? []
        return UpcomingEventsEntry(date: .now, pet: selectedPet, events: events)
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

    private var header: some View {
        HStack(spacing: 6) {
            Text(entry.pet?.name ?? "Mascota")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("• Próximo")
                .font(.caption)
                .foregroundStyle(.secondary)
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

struct BonesUpcomingEventsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BonesUpcomingEventsWidget",
                               intent: PetSelectionIntent.self,
                               provider: UpcomingEventsProvider()) { entry in
            BonesUpcomingEventsWidgetView(entry: entry)
        }
        .configurationDisplayName("Próximos de tu mascota")
        .description("Muestra los próximos eventos de una mascota.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
                        ])
}

#Preview("Small vacío", as: .systemSmall) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Loki"),
                        events: [])
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
                        ])
}

#Preview("Medium vacío", as: .systemMedium) {
    BonesUpcomingEventsWidget()
} timeline: {
    UpcomingEventsEntry(date: .now,
                        pet: WidgetPetSummary(id: "preview", name: "Kira"),
                        events: [])
}

