//
//  EventSection.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import Foundation

struct EventSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [any BasicEvent]
}
