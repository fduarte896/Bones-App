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
        
        let all: [any BasicEvent] =
            fetch(Medication.self) +
            fetch(Vaccine.self) +
            fetch(Deworming.self) +
            fetch(Grooming.self) +
            fetch(WeightEntry.self)
        
        eventsByDay = Dictionary(grouping: all) { event in
            Calendar.current.startOfDay(for: event.date)
        }
    }
    
    func events(on day: Date) -> [any BasicEvent] {
        eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
    }
}
