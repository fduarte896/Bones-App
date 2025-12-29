//// NextEventPublisher.swift
//import Foundation
//import SwiftData
//import WidgetKit
//
//@MainActor
//final class NextEventPublisher: ObservableObject {
//    static let shared = NextEventPublisher()
//    private init() {}
//    
//    // Llama esto cuando haya cambios o en onAppear
//    func update(using context: ModelContext, appGroupID: String) {
//        let now = Date()
//        
//        func fetch<T: PersistentModel>(_ type: T.Type,
//                                       predicate: Predicate<T>,
//                                       sort: SortDescriptor<T>) -> [T] {
//            var desc = FetchDescriptor<T>(predicate: predicate)
//            desc.sortBy = [sort]
//            return (try? context.fetch(desc)) ?? []
//        }
//        
//        // Filtramos pendientes con fecha >= ahora; excluimos WeightEntry
//        let meds: [Medication] = fetch(Medication.self,
//                                       predicate: #Predicate { !$0.isCompleted && $0.date >= now },
//                                       sort: .init(\.date, order: .forward))
//        let vacs: [Vaccine] = fetch(Vaccine.self,
//                                     predicate: #Predicate { !$0.isCompleted && $0.date >= now },
//                                     sort: .init(\.date, order: .forward))
//        let dews: [Deworming] = fetch(Deworming.self,
//                                       predicate: #Predicate { !$0.isCompleted && $0.date >= now },
//                                       sort: .init(\.date, order: .forward))
//        let grooms: [Grooming] = fetch(Grooming.self,
//                                        predicate: #Predicate { !$0.isCompleted && $0.date >= now },
//                                        sort: .init(\.date, order: .forward))
//        
//        // El más cercano global
//        let candidates: [(Date, NextEventPayload)] = [
//            meds.first.map { m in (m.date, NextEventPayload(id: m.id,
//                                                            kind: .medication,
//                                                            title: m.name,
//                                                            petName: m.pet?.name ?? "",
//                                                            date: m.date,
//                                                            symbolName: "pills.fill")) },
//            vacs.first.map { v in (v.date, NextEventPayload(id: v.id,
//                                                            kind: .vaccine,
//                                                            title: v.vaccineName,
//                                                            petName: v.pet?.name ?? "",
//                                                            date: v.date,
//                                                            symbolName: "syringe")) },
//            dews.first.map { d in (d.date, NextEventPayload(id: d.id,
//                                                            kind: .deworming,
//                                                            title: (d.notes?.isEmpty == false ? d.notes! : "Desparasitación"),
//                                                            petName: d.pet?.name ?? "",
//                                                            date: d.date,
//                                                            symbolName: "ladybug.fill")) },
//            grooms.first.map { g in (g.date, NextEventPayload(id: g.id,
//                                                              kind: .grooming,
//                                                              title: g.displayName,
//                                                              petName: g.pet?.name ?? "",
//                                                              date: g.date,
//                                                              symbolName: "scissors")) }
//        ].compactMap { $0 }
//        
//        let next = candidates.min(by: { $0.0 < $1.0 })?.1
//        NextEventStore.save(next, appGroupID: appGroupID)
//        
//        // Pide recarga de timelines
//        WidgetCenter.shared.reloadAllTimelines()
//    }
//}
//
//// ViewModifier que orquesta el “update” usando el ModelContext del entorno
//import SwiftUI
//
//struct NextEventSyncer: ViewModifier {
//    @Environment(\.modelContext) private var context
//    let appGroupID: String
//    
//    func body(content: Content) -> some View {
//        content
//            .onAppear {
//                NextEventPublisher.shared.update(using: context, appGroupID: appGroupID)
//            }
//            .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
//                NextEventPublisher.shared.update(using: context, appGroupID: appGroupID)
//            }
//    }
//}
//
//extension View {
//    func syncNextEvent(appGroupID: String) -> some View {
//        self.modifier(NextEventSyncer(appGroupID: appGroupID))
//    }
//}
