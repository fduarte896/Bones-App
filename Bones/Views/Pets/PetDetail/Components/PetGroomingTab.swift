//
//  PetGroomingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetGroomingTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    @AppStorage("appCurrencyCode") private var appCurrencyCode: String = (Locale.current.currency?.identifier ?? "USD")
    
    private var currencyCode: String {
        if appCurrencyCode == "AUTO" {
            return Locale.current.currency?.identifier ?? "USD"
        }
        return appCurrencyCode
    }
    
    // Secciones agrupadas por día: primero próximas (asc), luego pasadas (desc)
    private var groupedSections: [(title: String, items: [Grooming])] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        
        // Dividir en próximas (>= hoy) y pasadas (< hoy)
        let upcoming = viewModel.groomings.filter { $0.date >= startOfToday }
        let past = viewModel.groomings.filter { $0.date < startOfToday }
        
        // Agrupar por día (startOfDay)
        func groupByDay(_ items: [Grooming]) -> [Date: [Grooming]] {
            Dictionary(grouping: items) { g in
                cal.startOfDay(for: g.date)
            }
        }
        
        // Títulos de sección
        func headerTitle(for day: Date) -> String {
            if cal.isDateInToday(day) { return "Hoy" }
            if cal.isDateInTomorrow(day) { return "Mañana" }
            if cal.isDateInYesterday(day) { return "Ayer" }
            // Ej.: "vie, 10 oct 2025"
            return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
        }
        
        // Ordenar y mapear a tuplas (title, items)
        let upcomingSections: [(String, [Grooming])] = groupByDay(upcoming)
            .sorted(by: { $0.key < $1.key }) // días ascendentes
            .map { day, items in
                let sorted = items.sorted { $0.date < $1.date } // dentro del día, por hora asc
                return (headerTitle(for: day), sorted)
            }
        
        let pastSections: [(String, [Grooming])] = groupByDay(past)
            .sorted(by: { $0.key > $1.key }) // días descendentes
            .map { day, items in
                let sorted = items.sorted { $0.date > $1.date } // dentro del día, por hora desc
                return (headerTitle(for: day), sorted)
            }
        
        return upcomingSections + pastSections
    }
    
    var body: some View {
        List {
            if viewModel.groomings.isEmpty {
                ContentUnavailableView("Sin citas de grooming",
                                       systemImage: "scissors")
            } else {
                ForEach(Array(groupedSections.enumerated()), id: \.offset) { _, section in
                    Section(section.title) {
                        ForEach(section.items, id: \.id) { groom in
                            NavigationLink {
                                EventDetailView(event: groom)
                            } label: {
                                GroomingRow(groom: groom, currencyCode: currencyCode)
                            }
                            // Swipe: completar
                            .swipeActions(edge: .leading) {
                                Button {
                                    groom.isCompleted.toggle()
                                    NotificationManager.shared.cancelNotification(id: groom.id)
                                    try? context.save()
                                    viewModel.fetchEvents()
                                } label: {
                                    Label("Completar", systemImage: "checkmark")
                                }.tint(.green)
                            }
                            // Swipe: borrar
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    NotificationManager.shared.cancelNotification(id: groom.id)
                                    context.delete(groom)
                                    try? context.save()
                                    viewModel.fetchEvents()
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            viewModel.fetchEvents()
        }
    }
}

// MARK: - Fila
private struct GroomingRow: View {
    @Bindable var groom: Grooming
    let currencyCode: String
    
    private var servicesText: String {
        groom.services.map { $0.displayName }.joined(separator: ", ")
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Descripción principal: servicios, o notes, o genérico
                Text(!servicesText.isEmpty
                     ? servicesText
                     : (groom.notes?.isEmpty == false ? groom.notes! : "Sesión de grooming"))
                    .fontWeight(.semibold)
                
                // Ubicación, si existe
                if let loc = groom.location, !loc.isEmpty {
                    Text("Lugar: \(loc)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Precio, si existe
                if let price = groom.totalPrice {
                    Text(price, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Fecha / hora
                Text(groom.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: groom.isCompleted ? "checkmark.circle.fill" : "scissors")
                .foregroundStyle(groom.isCompleted ? .green : .accentColor)
        }
    }
}

// MARK: - Previews

#Preview("Grooming – Con datos") {
    let container = GroomingPreviewData.makeContainer()
    let pet = GroomingPreviewData.seedGroomings(in: container)
    return PetGroomingTabPreviewHost(pet: pet)
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Grooming – Vacío") {
    let container = GroomingPreviewData.makeContainer()
    let pet = GroomingPreviewData.emptyPet(in: container)
    return PetGroomingTabPreviewHost(pet: pet)
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

// Host que crea el VM y le inyecta el context del entorno
private struct PetGroomingTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    
    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }
    
    var body: some View {
        NavigationStack {
            PetGroomingTab(viewModel: vm)
        }
        .onAppear {
            vm.inject(context: context)
        }
    }
}

// Datos de ejemplo para previews
private enum GroomingPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Grooming.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
    
    @discardableResult
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }
    
    @discardableResult
    static func seedGroomings(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        
        let now = Date()
        let g1 = Grooming(date: now.addingTimeInterval(2 * 24 * 3600),
                          pet: pet,
                          location: "Pet Spa",
                          notes: nil,
                          services: [.bano, .cortePelo, .corteUnas],
                          totalPrice: 550)
        let g2 = Grooming(date: now.addingTimeInterval(10 * 24 * 3600),
                          pet: pet,
                          location: "Groom&Love",
                          notes: nil,
                          services: [.limpiezaOjos, .limpiezaOidos],
                          totalPrice: 320)
        let g3 = Grooming(date: now.addingTimeInterval(-5 * 24 * 3600),
                          pet: pet,
                          location: "Pet Spa",
                          notes: "Baño antipulgas",
                          services: [.bano, .glandulas],
                          totalPrice: 450)
        g3.isCompleted = true
        
        ctx.insert(g1)
        ctx.insert(g2)
        ctx.insert(g3)
        try? ctx.save()
        return pet
    }
}
