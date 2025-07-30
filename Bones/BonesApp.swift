//
//  BonesApp.swift
//  Bones
//
//  Created by Felipe Duarte on 10/07/25.
//

import SwiftUI
import SwiftData

@main
struct BonesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Pet.self,
                    Medication.self,
                    Vaccine.self,
                    Deworming.self,
                    Grooming.self,
                    WeightEntry.self
                ])
                .task {
                    await NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
