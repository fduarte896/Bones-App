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
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    @Query(sort: \Pet.name) private var pets: [Pet]
    @State private var showOnboarding = false
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
        .onAppear {
            ensureOnboardingIfNeeded()
            syncOnboardingVisibility()
        }
        .onChange(of: didCompleteOnboarding) { _, _ in
            syncOnboardingVisibility()
        }
        .onChange(of: pets.count) { _, _ in
            ensureOnboardingIfNeeded()
            syncOnboardingVisibility()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(didCompleteOnboarding: $didCompleteOnboarding)
        }
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

    private func ensureOnboardingIfNeeded() {
        if !didCompleteOnboarding, !pets.isEmpty {
            didCompleteOnboarding = true
        }
    }

    private func syncOnboardingVisibility() {
        showOnboarding = !didCompleteOnboarding
    }
}

#Preview {
    ContentView()
}
