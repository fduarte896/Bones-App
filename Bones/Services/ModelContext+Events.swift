//
//  ModelContext+Events.swift
//  Bones
//

import SwiftData

extension ModelContext {
    func fetchAll<T: BasicEvent>(_ type: T.Type) -> [T] {
        (try? fetch(FetchDescriptor<T>())) ?? []
    }

    func fetchAllEvents() -> [any BasicEvent] {
        var all: [any BasicEvent] = []
        all.append(contentsOf: fetchAll(Vaccine.self))
        all.append(contentsOf: fetchAll(Deworming.self))
        all.append(contentsOf: fetchAll(WeightEntry.self))
        return all
    }
}
