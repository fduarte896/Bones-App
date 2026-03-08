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
    let entry: UpcomingEventsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(entry.pet?.name ?? "Mascota")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• Próximo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                        TagChip(text: next.type, tint: .blue)
                        Text(shortDate(next.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Sin próximos")
                    .font(.headline)
                Text("Agrega eventos para verlos aquí")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(widgetURL())
    }

    private func widgetURL() -> URL? {
        guard let pet = entry.pet else { return URL(string: "bones://events") }
        var components = URLComponents()
        components.scheme = "bones"
        components.host = "events"
        components.queryItems = [
            URLQueryItem(name: "petId", value: pet.id),
            URLQueryItem(name: "petName", value: pet.name)
        ]
        return components.url
    }

    private func timeLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if cal.isDateInTomorrow(date) {
            return "Mañana"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Hoy"
        }
        if cal.isDateInTomorrow(date) {
            return "Mañana"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
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
