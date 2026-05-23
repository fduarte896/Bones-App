//
//  QuickAddGenerator.swift
//  BonesAppTests
//
//  Created by Felipe Duarte on 30/07/25.
//

import Foundation

struct QuickAddGenerator {
    static func generateDateSeries(
        baseDate: Date,
        repeatCount: Int,
        intervalHours: Int
    ) -> [Date] {
        let cal = Calendar.current
        var dates: [Date] = [baseDate]
        var next = baseDate
        for _ in 0..<repeatCount {
            next = cal.date(byAdding: .hour, value: intervalHours, to: next)!
            dates.append(next)
        }
        return dates
    }
}
