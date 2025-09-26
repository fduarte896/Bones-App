//
//  CalendarEventsViewModel.swift
//  Bones
//
//  Created by Felipe Duarte on 30/07/25.
//


import Foundation
import SwiftData
import SwiftUI


@MainActor
final class CalendarEventsViewModel: ObservableObject {
    @Published var eventsByDay: [Date: [any BasicEvent]] = [:]
    private var context: ModelContext?
    
    func inject(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        fetchAll()
    }
    
    func fetchAll() {
        guard let context else { return }
        
        func fetch<T: BasicEvent & PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }
        
        var all: [any BasicEvent] = []
        all.append(contentsOf: fetch(Medication.self).map { $0 as any BasicEvent })
        all.append(contentsOf: fetch(Vaccine.self).map { $0 as any BasicEvent })
        all.append(contentsOf: fetch(Deworming.self).map { $0 as any BasicEvent })
        all.append(contentsOf: fetch(Grooming.self).map { $0 as any BasicEvent })
        all.append(contentsOf: fetch(WeightEntry.self).map { $0 as any BasicEvent })
        
        eventsByDay = Dictionary(grouping: all) { event in
            Calendar.current.startOfDay(for: event.date)
        }
    }
    
    func events(on day: Date) -> [any BasicEvent] {
        eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
    }
}

