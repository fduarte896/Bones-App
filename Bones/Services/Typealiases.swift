//
//  Typealiases.swift
//  Bones
//
//  Created by Felipe Duarte on 30/07/25.
//

import Foundation
import SwiftData

typealias Pred<T> = T where T: BasicEvent & PersistentModel

enum IntervalUnit: String, CaseIterable, Identifiable {
    case hours, days, weeks, months
    var id: Self { self }
    var label: String {
        switch self {
        case .hours:  "horas"
        case .days:   "días"
        case .weeks:  "semanas"
        case .months: "meses"
        }
    }
}

enum ScheduleMode: String, CaseIterable, Identifiable {
    case interval, perDay
    var id: Self { self }
    var label: String { self == .interval ? "Por intervalo" : "Por día" }
}

enum MedicationScheduling {
    static func addInterval(_ value: Int, unit: IntervalUnit, to date: Date) -> Date {
        let cal = Calendar.current
        switch unit {
        case .hours:  return cal.date(byAdding: .hour,  value: value, to: date) ?? date
        case .days:   return cal.date(byAdding: .day,   value: value, to: date) ?? date
        case .weeks:  return cal.date(byAdding: .day,   value: 7 * value, to: date) ?? date
        case .months: return cal.date(byAdding: .month, value: value, to: date) ?? date
        }
    }
    
    static func preview(start: Date,
                        mode: ScheduleMode,
                        intervalValue: Int,
                        intervalUnit: IntervalUnit,
                        durationDays: Int,
                        timesPerDay: Int) -> [Date] {
        let cal = Calendar.current
        switch mode {
        case .interval:
            let end = cal.date(byAdding: .day, value: durationDays, to: start) ?? start
            var dates: [Date] = [start]
            var current = start
            while true {
                let next = addInterval(intervalValue, unit: intervalUnit, to: current)
                if next > end { break }
                dates.append(next)
                current = next
            }
            return dates
        case .perDay:
            let total = max(1, timesPerDay * durationDays)
            let stepHours = Int((24.0 / max(1.0, Double(timesPerDay))).rounded())
            var dates: [Date] = [start]
            var current = start
            if total > 1 {
                for _ in 1..<total {
                    current = cal.date(byAdding: .hour, value: stepHours, to: current) ?? current
                    dates.append(current)
                }
            }
            return dates
        }
    }
    
    static func intervalSummary(start: Date,
                                durationDays: Int,
                                stepValue: Int,
                                stepUnit: IntervalUnit) -> (total: Int, last: Date)? {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: durationDays, to: start) ?? start
        var current = start
        var last = start
        var count = 1
        while true {
            let next = addInterval(stepValue, unit: stepUnit, to: current)
            if next > end { break }
            last = next
            count += 1
            current = next
        }
        return (count, last)
    }
}
