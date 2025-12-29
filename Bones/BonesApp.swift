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
    @AppStorage("didSeedDemoDog") private var didSeedDemoDog: Bool = false

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
                    
                    // Sembrar demo solo una vez (primer arranque)
                    if !didSeedDemoDog {
                        let container = try? ModelContainer(for: 
                                                                Pet.self, Medication.self, Vaccine.self, Deworming.self, Grooming.self, WeightEntry.self
                        )
                        if let container, (try? ModelContext(container).fetch(FetchDescriptor<Pet>()))?.isEmpty ?? true {
                            DemoSeeder.seedDemoDogWithMedications(in: container)
                        }
                        didSeedDemoDog = true
                    }
                }
        }
    }
}

