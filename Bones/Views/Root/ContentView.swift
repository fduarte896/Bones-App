//
//  ContentView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: Tab = .pets
    @Environment(\.modelContext) private var context

    enum Tab { case pets, events, settings }

    var body: some View {
        TabView(selection: $selection) {
            PetsListView()
                .tabItem { Label("Mascotas", systemImage: "pawprint") }
                .tag(Tab.pets)

            EventsListView(context: context)
                .tabItem { Label("Eventos", systemImage: "calendar") }
                .tag(Tab.events)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gear") }
                .tag(Tab.settings)
        }
    }
}

#Preview {
    ContentView()
}
