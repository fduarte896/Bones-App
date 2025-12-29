//// BonesNextEventWidget.swift
//import WidgetKit
//import SwiftUI
//import AppIntents
//
//private let appGroupID = "group.Felipeduarte.bones"
//
//struct NextEventEntry: TimelineEntry {
//    let date: Date
//    let payload: NextEventPayload?
//}
//
//@available(iOS 18.0, *)
//struct NextEventProvider: AppIntentTimelineProvider {
//    // Declara los tipos asociados del provider
//    typealias Intent = ConfigurationAppIntent
//    typealias Entry = NextEventEntry
//
//    func placeholder(in context: Context) -> NextEventEntry {
//        NextEventEntry(date: .now, payload: .init(id: UUID(),
//                                                  kind: .medication,
//                                                  title: "Amoxicilina (dosis 1/3)",
//                                                  petName: "Loki",
//                                                  date: .now.addingTimeInterval(3600),
//                                                  symbolName: "pills.fill"))
//    }
//
//    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> NextEventEntry {
//        let payload = NextEventStore.load(appGroupID: appGroupID)
//        return NextEventEntry(date: .now, payload: payload)
//    }
//
//    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<NextEventEntry> {
//        let payload = NextEventStore.load(appGroupID: appGroupID)
//        let now = Date()
//        let entry = NextEventEntry(date: now, payload: payload)
//
//        // Próxima actualización: a la hora del evento si hay payload; si no, en 3 horas
//        let nextRefresh: Date = {
//            if let p = payload {
//                return p.date.addingTimeInterval(10)
//            } else {
//                return now.addingTimeInterval(3 * 3600)
//            }
//        }()
//
//        return Timeline(entries: [entry], policy: .after(nextRefresh))
//    }
//}
//
//@available(iOS 18.0, *)
//struct NextEventWidgetView: View {
//    @Environment(\.widgetFamily) private var family
//    let entry: NextEventEntry
//
//    var body: some View {
//        // Envuelve TODO el contenido en un Button(intent:) para que cualquier toque abra la app
//        Button(intent: OpenAppIntent()) {
//            switch family {
//            case .systemSmall:
//                VStack(alignment: .leading, spacing: 6) {
//                    HStack(spacing: 8) {
//                        Image(systemName: entry.payload?.symbolName ?? "calendar")
//                            .font(.title2)
//                        Text("Próximo")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }
//                    Text(entry.payload?.title ?? "Nada pendiente")
//                        .font(.headline)
//                        .lineLimit(2)
//                    if let p = entry.payload {
//                        HStack(spacing: 6) {
//                            Text(relativeDate(p.date))
//                            Text("•")
//                            Text(p.petName)
//                        }
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                    }
//                    Spacer()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//                .containerBackground(.background, for: .widget)
//
//            case .systemMedium:
//                HStack(alignment: .center, spacing: 12) {
//                    Image(systemName: entry.payload?.symbolName ?? "calendar")
//                        .font(.system(size: 36, weight: .semibold))
//                        .frame(width: 44, height: 44)
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Próximo evento")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                        Text(entry.payload?.title ?? "Nada pendiente")
//                            .font(.headline)
//                            .lineLimit(2)
//                        if let p = entry.payload {
//                            HStack(spacing: 8) {
//                                Text(longDate(p.date))
//                                Text("•")
//                                Text(p.petName)
//                            }
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                        }
//                    }
//                    Spacer()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
//                .containerBackground(.background, for: .widget)
//
//            default:
//                VStack { Text("Próximo evento") }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .containerBackground(.background, for: .widget)
//            }
//        }
//        // El Button ocupa toda el área del widget; no necesitas .widgetURL ni .appIntent aquí.
//        .buttonStyle(.plain)
//    }
//
//    private func relativeDate(_ date: Date) -> String {
//        let cal = Calendar.current
//        if cal.isDateInToday(date) {
//            return "Hoy " + date.formatted(date: .omitted, time: .shortened)
//        } else if cal.isDateInTomorrow(date) {
//            return "Mañana " + date.formatted(date: .omitted, time: .shortened)
//        } else {
//            return date.formatted(date: .abbreviated, time: .shortened)
//        }
//    }
//    private func longDate(_ date: Date) -> String {
//        relativeDate(date)
//    }
//}
//
//@available(iOS 18.0, *)
//struct BonesNextEventWidget: Widget {
//    var body: some WidgetConfiguration {
//        AppIntentConfiguration(kind: "BonesNextEventWidget",
//                               intent: ConfigurationAppIntent.self,
//                               provider: NextEventProvider()) { entry in
//            NextEventWidgetView(entry: entry)
//        }
//        .configurationDisplayName("Próximo evento")
//        .description("Muestra el próximo evento pendiente entre todas tus mascotas.")
//        .supportedFamilies([.systemSmall, .systemMedium])
//    }
//}
//
//// Intent de configuración “vacío”: DEBE conformar a WidgetConfigurationIntent
//@available(iOS 18.0, *)
//struct ConfigurationAppIntent: WidgetConfigurationIntent {
//    static var title: LocalizedStringResource = "Configuración"
//    // Sin parámetros por ahora
//}
