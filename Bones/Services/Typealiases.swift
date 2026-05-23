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
