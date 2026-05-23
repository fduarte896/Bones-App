import Observation
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CalendarEventsViewModel {
    var eventsByDay: [Date: [any BasicEvent]] = [:]
    private var context: ModelContext?

    func inject(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        fetchAll()
    }

    func fetchAll() {
        guard let context else { return }
        let all = context.fetchAllEvents()
        eventsByDay = Dictionary(grouping: all) { event in
            Calendar.current.startOfDay(for: event.date)
        }
    }

    func events(on day: Date) -> [any BasicEvent] {
        eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
    }
}
