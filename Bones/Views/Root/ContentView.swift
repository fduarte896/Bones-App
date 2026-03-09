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
    @AppStorage("eventsDeepLinkPetID") private var eventsDeepLinkPetID: String = ""
    @AppStorage("eventsDeepLinkPetName") private var eventsDeepLinkPetName: String = ""
    @AppStorage("eventsDeepLinkAction") private var eventsDeepLinkAction: String = ""

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
        .syncWidgetData()
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "bones", url.host == "events" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let petID = components?.queryItems?.first(where: { $0.name == "petId" })?.value
        let petName = components?.queryItems?.first(where: { $0.name == "petName" })?.value
        let action = components?.queryItems?.first(where: { $0.name == "action" })?.value

        if let petID {
            eventsDeepLinkPetID = petID
            eventsDeepLinkPetName = petName ?? ""
        }
        if let action {
            eventsDeepLinkAction = action
        }
        if petID != nil || action != nil {
            selection = .events
        }
    }
}

#Preview {
    ContentView()
}
