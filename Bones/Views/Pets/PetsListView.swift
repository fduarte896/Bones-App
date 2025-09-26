//
//  PetsListView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData
import PhotosUI          // si muestras miniaturas
import UIKit             // para UIImage en previews

struct PetsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var pets: [Pet]   // alfabético
    
    @State private var isPresentingAdd = false
    @State private var petToEdit: Pet?   // nuevo state
    
    // 2 columnas en iPhone, 3-4 en iPad/landscape (modo compacto)
    private let columns = [ GridItem(.adaptive(minimum: 150), spacing: 16) ]
    // Modo detallado (tarjetas más anchas/altas)
    private let detailedColumns = [ GridItem(.adaptive(minimum: 220), spacing: 16) ]
    
    var body: some View {
        NavigationStack {
            if pets.isEmpty {
                VStack(spacing: 24) {
                    ContentUnavailableView("Sin mascotas",
                                           systemImage: "pawprint")
                    
                    Button {
                        isPresentingAdd = true
                    } label: {
                        Label("Añadir mascota", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )
                            .foregroundStyle(.white)
                    }
                }
                .sheet(isPresented: $isPresentingAdd) {
                    AddPetSheet()
                }
                .sheet(item: $petToEdit) { pet in
                    EditPetSheet(pet: pet)
                }
            }
            else if pets.count == 1, let pet = pets.first {
                // Dashboard para una sola mascota
                SinglePetDashboardView(pet: pet)
                    .navigationTitle("Resumen")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink {
                                PetDetailView(pet: pet)
                            } label: {
                                Image(systemName: "chevron.right.circle")
                            }
                            .accessibilityLabel("Ver detalle")
                        }
                    }
                    .sheet(item: $petToEdit) { pet in
                        EditPetSheet(pet: pet)
                    }
            }
            else if (2...3).contains(pets.count) {
                // Carrusel paginado para 2–3 mascotas, cada página replica el mini-dashboard
                TabView {
                    ForEach(pets) { pet in
                        VStack(spacing: 0) {
                            PetCarouselCard(pet: pet)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            Spacer(minLength: 0) // ancla arriba el contenido
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .navigationTitle("Mascotas")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { isPresentingAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingAdd) {
                    AddPetSheet()
                }
                .sheet(item: $petToEdit) { pet in
                    EditPetSheet(pet: pet)
                }
            }
            else if (4...6).contains(pets.count) {
                // Grilla detallada (mejor aprovechamiento del espacio)
                ScrollView {
                    LazyVGrid(columns: detailedColumns, spacing: 16) {
                        ForEach(pets) { pet in
                            NavigationLink {
                                PetDetailView(pet: pet)
                            } label: {
                                PetDetailedCardView(
                                    pet: pet,
                                    nextEventDate: nextEvent(for: pet),
                                    lastWeight: lastWeight(for: pet)
                                )
                            }
                            .contextMenu {
                                Divider()
                                Button("Eliminar", systemImage: "trash", role: .destructive) {
                                    context.delete(pet)
                                    try? context.save()
                                }
                                Button("Editar", systemImage: "pencil") {
                                    petToEdit = pet
                                    isPresentingAdd = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .navigationTitle("Mascotas")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { isPresentingAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingAdd) {
                    AddPetSheet()
                }
                .sheet(item: $petToEdit) { pet in
                    EditPetSheet(pet: pet)
                }
            }
            else {
                // 7 o más: grilla compacta (actual)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(pets) { pet in
                            NavigationLink {
                                PetDetailView(pet: pet)
                            } label: {
                                PetCardView(
                                    pet: pet,
                                    nextEventDate: nextEvent(for: pet)
                                )
                            }
                            .contextMenu {
                                Divider()
                                Button("Eliminar", systemImage: "trash", role: .destructive) {
                                    context.delete(pet)
                                    try? context.save()
                                }
                                Button("Editar", systemImage: "pencil") {
                                    petToEdit = pet
                                    isPresentingAdd = false        // por claridad
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .navigationTitle("Mascotas")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { isPresentingAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingAdd) {
                    AddPetSheet()
                }
                .sheet(item: $petToEdit) { pet in
                    EditPetSheet(pet: pet)
                }
            }
        }
    }
    
    // --- helpers para tarjetas ---
    private func nextEvent(for pet: Pet) -> Date? {
        let now = Date()

        // 1. Medicamentos
        let medDate = (try? context.fetch(
            FetchDescriptor<Medication>(sortBy: [SortDescriptor(\Medication.date)])
        ))?
        .first { $0.pet?.id == pet.id && $0.date >= now }?
        .date

        // 2. Vacunas
        let vacDate = (try? context.fetch(
            FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\Vaccine.date)])
        ))?
        .first { $0.pet?.id == pet.id && $0.date >= now }?
        .date

        // 3. Desparasitación
        let dewDate = (try? context.fetch(
            FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\Deworming.date)])
        ))?
        .first { $0.pet?.id == pet.id && $0.date >= now }?
        .date

        // 4. Grooming
        let groDate = (try? context.fetch(
            FetchDescriptor<Grooming>(sortBy: [SortDescriptor(\Grooming.date)])
        ))?
        .first { $0.pet?.id == pet.id && $0.date >= now }?
        .date

        // Devuelve la fecha más cercana (mínima no-nula)
        return [medDate, vacDate, dewDate, groDate]
            .compactMap { $0 }
            .min()
    }
    
    private func lastWeight(for pet: Pet) -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }
}

// MARK: - Dashboard para una sola mascota

private struct SinglePetDashboardView: View {
    @Environment(\.modelContext) private var context
    let pet: Pet
    
    @State private var showingQuickAdd = false
    @State private var quickAddKind: EventKind = .medication
    @State private var isPresentingEdit = false
    @State private var showingDeleteAlert = false
    @State private var isPresentingAddPet = false   // FAB: añadir otra mascota
    
    // Layout de tarjetas
    private let cardsColumns = [ GridItem(.adaptive(minimum: 160), spacing: 12) ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                
                // Tarjetas de resumen
                LazyVGrid(columns: cardsColumns, spacing: 12) {
                    nextEventCard
                    lastVaccineCard
                    lastDewormingCard
                    currentWeightCard
                }
                .padding(.horizontal)
                
                // Botón eliminar mascota
                VStack(spacing: 8) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Eliminar mascota", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Text("Se eliminarán también todos sus eventos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical, 12)
        }
        // FAB “+” para añadir otra mascota
        .overlay(alignment: .bottomTrailing) {
            Button {
                isPresentingAddPet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityLabel("Añadir mascota")
        }
        .sheet(isPresented: $showingQuickAdd) {
            EventQuickAddSheet(pet: pet, initialKind: quickAddKind)
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditPetSheet(pet: pet)
        }
        .sheet(isPresented: $isPresentingAddPet) {
            AddPetSheet()
        }
        .alert("¿Eliminar mascota?", isPresented: $showingDeleteAlert) {
            Button("Eliminar", role: .destructive) { deletePet() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    // Cabecera con foto + datos + acciones
    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            // Foto
            Group {
                if let data = pet.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                } else {
                    Image(systemName: "pawprint.fill")
                        .resizable().scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding(20)
                }
            }
            .frame(width: 96, height: 96)
            .background(Color(.systemGray6))
            .clipShape(Circle())
            
            // Datos básicos
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.title2).bold()
                HStack(spacing: 6) {
                    Text(pet.sex.displayName)            // ← Español
                    Text("·")
                    Text(pet.species.rawValue.capitalized)
                    if let breed = pet.breed, !breed.isEmpty {
                        Text("·")
                        Text(breed)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                if let age = ageString(for: pet.birthDate) {
                    Text(age)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    Button {
                        isPresentingEdit = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    
                    NavigationLink {
                        PetDetailView(pet: pet)
                    } label: {
                        Label("Ver detalle", systemImage: "chevron.right.circle")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }

        }
        .padding(.horizontal)
    }
    
    // MARK: - Tarjetas
    
    private var nextEventCard: some View {
        let info = nextEventInfo()
        return InfoCard(
            icon: "calendar",
            title: "Próximo evento",
            primary: info.map { $0.date.formatted(date: .abbreviated, time: .shortened) } ?? "Sin eventos",
            secondary: info?.type
        )
        .contextMenu {
            Button("Nuevo evento", systemImage: "plus") {
                quickAddKind = .medication
                showingQuickAdd = true
            }
        }
    }
    
    private var lastVaccineCard: some View {
        let last = lastVaccine()
        return InfoCard(
            icon: "syringe",
            title: "Última \n vacuna",
            primary: last?.date.formatted(date: .abbreviated, time: .omitted) ?? "Nunca",
            secondary: last.map { esRelativeFormatter.localizedString(for: $0.date, relativeTo: Date()) } // ← Español
        )
        .contextMenu {
            Button("Añadir vacuna", systemImage: "plus") {
                quickAddKind = .vaccine
                showingQuickAdd = true
            }
        }
    }
    
    private var lastDewormingCard: some View {
        let last = lastDeworming()
        return InfoCard(
            icon: "ladybug.fill",
            title: "Última desparasitación",
            primary: last?.date.formatted(date: .abbreviated, time: .omitted) ?? "Nunca",
            secondary: last.map { esRelativeFormatter.localizedString(for: $0.date, relativeTo: Date()) } // ← Español
        )
    }
    
    private var currentWeightCard: some View {
        let last = lastWeight()
        return InfoCard(
            icon: "scalemass",
            title: "Peso actual",
            primary: last.map { String(format: "%.1f kg", $0.weightKg) } ?? "—",
            secondary: last.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        )
        .contextMenu {
            Button("Añadir peso", systemImage: "plus") {
                quickAddKind = .weight
                showingQuickAdd = true
            }
        }
    }
    
    // MARK: - Fetch helpers SIN #Predicate (evita errores de macro)
    private func nextEventInfo() -> (date: Date, type: String)? {
        let now = Date()
        
        let medDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let vacDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let dewDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let groDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Grooming>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let pairs: [(Date, String)] = [
            medDate.map { ($0, "Medicamento") },
            vacDate.map { ($0, "Vacuna") },
            dewDate.map { ($0, "Desparasitación") },
            groDate.map { ($0, "Grooming") }
        ]
        .compactMap { $0 }
        
        guard let minPair = pairs.min(by: { $0.0 < $1.0 }) else { return nil }
        return (date: minPair.0, type: minPair.1)
    }
    
    private func lastVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now }
    }
    
    private func lastDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now }
    }
    
    private func lastWeight() -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }
    
    // MARK: - Delete
    private func deletePet() {
        // 1) Cancelar notificaciones de todos sus eventos
        let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        let vacs = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let grooms = (try? context.fetch(FetchDescriptor<Grooming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        
        for e in meds where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in vacs where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in grooms where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in weights where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        
        // 2) Eliminar la mascota (cascade borra relaciones)
        context.delete(pet)
        try? context.save()
        
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        
        // 3) Notificar cambios para que otras vistas refresquen
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// Tarjeta del carrusel (página) para 2–3 mascotas – replica el mini-dashboard
private struct PetCarouselCard: View {
    @Environment(\.modelContext) private var context
    let pet: Pet
    
    @State private var showingQuickAdd = false
    @State private var quickAddKind: EventKind = .medication
    @State private var isPresentingEdit = false
    @State private var showingDeleteAlert = false
    
    private let cardsColumns = [ GridItem(.adaptive(minimum: 160), spacing: 12) ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cabecera (idéntica a la de 1 mascota, con acciones)
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let data = pet.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                    } else {
                        Image(systemName: "pawprint.fill")
                            .resizable().scaledToFit()
                            .foregroundStyle(.secondary)
                            .padding(20)
                    }
                }
                .frame(width: 96, height: 96)
                .background(Color(.systemGray6))
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.title2).bold()
                    HStack(spacing: 6) {
                        Text(pet.sex.displayName)
                        Text("·")
                        Text(pet.species.rawValue.capitalized)
                        if let breed = pet.breed, !breed.isEmpty {
                            Text("·")
                            Text(breed)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    if let age = ageString(for: pet.birthDate) {
                        Text(age)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Button {
                            isPresentingEdit = true
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                        
                        NavigationLink {
                            PetDetailView(pet: pet)
                        } label: {
                            Label("Ver detalle", systemImage: "chevron.right.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
            }
            
            // Tarjetas de resumen (idénticas a 1 mascota)
            LazyVGrid(columns: cardsColumns, spacing: 0) {
                nextEventCard
                lastVaccineCard
                lastDewormingCard
                currentWeightCard
            }
            
            // Botón eliminar mascota (como en 1 mascota)
            VStack(spacing: 8) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Eliminar mascota", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Text("Se eliminarán también todos sus eventos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .contextMenu {
            Divider()
            Button("Eliminar", systemImage: "trash", role: .destructive) {
                showingDeleteAlert = true
            }
            Button("Editar", systemImage: "pencil") {
                isPresentingEdit = true
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            EventQuickAddSheet(pet: pet, initialKind: quickAddKind)
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditPetSheet(pet: pet)
        }
        .alert("¿Eliminar mascota?", isPresented: $showingDeleteAlert) {
            Button("Eliminar", role: .destructive) { deletePet() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Tarjetas (idénticas a SinglePetDashboardView)
    private var nextEventCard: some View {
        let info = nextEventInfo()
        return InfoCard(
            icon: "calendar",
            title: "Próximo evento",
            primary: info.map { $0.date.formatted(date: .abbreviated, time: .shortened) } ?? "Sin eventos",
            secondary: info?.type
        )
        .contextMenu {
            Button("Nuevo evento", systemImage: "plus") {
                quickAddKind = .medication
                showingQuickAdd = true
            }
        }
    }
    
    private var lastVaccineCard: some View {
        let last = lastVaccine()
        return InfoCard(
            icon: "syringe",
            title: "Última \n vacuna",
            primary: last?.date.formatted(date: .abbreviated, time: .omitted) ?? "Nunca",
            secondary: last.map { esRelativeFormatter.localizedString(for: $0.date, relativeTo: Date()) }
        )
        .contextMenu {
            Button("Añadir vacuna", systemImage: "plus") {
                quickAddKind = .vaccine
                showingQuickAdd = true
            }
        }
    }
    
    private var lastDewormingCard: some View {
        let last = lastDeworming()
        return InfoCard(
            icon: "ladybug.fill",
            title: "Última desparasitación",
            primary: last?.date.formatted(date: .abbreviated, time: .omitted) ?? "Nunca",
            secondary: last.map { esRelativeFormatter.localizedString(for: $0.date, relativeTo: Date()) }
        )
    }
    
    private var currentWeightCard: some View {
        let last = lastWeight()
        return InfoCard(
            icon: "scalemass",
            title: "Peso actual",
            primary: last.map { String(format: "%.1f kg", $0.weightKg) } ?? "—",
            secondary: last.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        )
        .contextMenu {
            Button("Añadir peso", systemImage: "plus") {
                quickAddKind = .weight
                showingQuickAdd = true
            }
        }
    }
    
    // MARK: - Fetch helpers (copiados de SinglePetDashboardView para evitar macro #Predicate)
    private func nextEventInfo() -> (date: Date, type: String)? {
        let now = Date()
        
        let medDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let vacDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let dewDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let groDate: Date? = {
            let items = (try? context.fetch(FetchDescriptor<Grooming>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
            return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }?.date
        }()
        
        let pairs: [(Date, String)] = [
            medDate.map { ($0, "Medicamento") },
            vacDate.map { ($0, "Vacuna") },
            dewDate.map { ($0, "Desparasitación") },
            groDate.map { ($0, "Grooming") }
        ]
        .compactMap { $0 }
        
        guard let minPair = pairs.min(by: { $0.0 < $1.0 }) else { return nil }
        return (date: minPair.0, type: minPair.1)
    }
    
    private func lastVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now }
    }
    
    private func lastDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now }
    }
    
    private func lastWeight() -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }
    
    // MARK: - Delete
    private func deletePet() {
        // 1) Cancelar notificaciones de todos sus eventos
        let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        let vacs = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let grooms = (try? context.fetch(FetchDescriptor<Grooming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        
        for e in meds where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in vacs where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in grooms where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in weights where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        
        // 2) Eliminar la mascota (cascade borra relaciones)
        context.delete(pet)
        try? context.save()
        
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        
        // 3) Notificar cambios para que otras vistas refresquen
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// Tarjeta detallada para grilla (4–6 mascotas)
private struct PetDetailedCardView: View {
    let pet: Pet
    let nextEventDate: Date?
    let lastWeight: WeightEntry?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Imagen ancha
            Group {
                if let data = pet.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Datos
            Text(pet.name)
                .font(.headline)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                Text(pet.species.rawValue.capitalized)
                if let breed = pet.breed, !breed.isEmpty {
                    Text("·")
                    Text(breed)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            
            // Próximo evento
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(nextEventDate?.formatted(date: .abbreviated, time: .shortened) ?? "Sin eventos próximos")
            }
            .font(.caption)
            .lineLimit(1)
            
            // Peso actual
            HStack(spacing: 8) {
                Image(systemName: "scalemass")
                    .foregroundStyle(.secondary)
                if let w = lastWeight {
                    Text(String(format: "%.1f kg", w.weightKg))
                    Spacer()
                    Text(w.date, format: .dateTime.day().month().year())
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                }
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Tarjeta simple reutilizable
private struct InfoCard: View {
    let icon: String
    let title: String
    let primary: String
    let secondary: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(primary)
                .font(.headline)
            if let secondary, !secondary.isEmpty {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Helper de edad local a este archivo
private func ageString(for birth: Date?) -> String? {
    guard let birth else { return nil }
    let comp = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
    let y = comp.year ?? 0, m = comp.month ?? 0
    switch (y, m) {
    case (0, 0):  return "Recién nacido"
    case (0, _):  return "\(m) mes\(m > 1 ? "es" : "")"
    default:      return "\(y) año\(y > 1 ? "s" : "") \(m) m"
    }
}

// MARK: - Localización auxiliar en este archivo

private extension Sex {
    var displayName: String {
        switch self {
        case .male:    return "Macho"
        case .female:  return "Hembra"
        case .unknown: return "Desconocido"
        }
    }
}

private let esRelativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "es")          // fuerza español
    f.unitsStyle = .full
    return f
}()

// MARK: - Previews

private enum PetsListPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Medication.self,
            Vaccine.self,
            Deworming.self,
            Grooming.self,
            WeightEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
    
    @discardableResult
    static func seedPets(count: Int, in container: ModelContainer, withEvents: Bool = true) -> [Pet] {
        let ctx = ModelContext(container)
        var result: [Pet] = []
        
        let namesDogs = ["Loki", "Kira", "Max", "Nala", "Toby", "Luna", "Rocky", "Milo"]
        let namesCats = ["Mishi", "Mía", "Simba", "Olivia", "Leo", "Coco", "Lola", "Chispa"]
        let breedsDogs = ["Husky", "Labrador", "Pastor", "Mestizo", "Beagle"]
        let breedsCats = ["Común", "Siamés", "Persa", "Mestizo"]
        let dogColors = ["Blanco", "Marrón", "Negro", "Gris"]
        let catColors = ["Gris", "Atigrado", "Negro", "Blanco"]
        
        let now = Date()
        let cal = Calendar.current
        
        for i in 0..<count {
            let isDog: Bool = (i % 2 == 0)
            let name: String = isDog ? namesDogs[i % namesDogs.count] : namesCats[i % namesCats.count]
            let species: Species = isDog ? .perro : .gato
            let sex: Sex = (i % 3 == 0) ? .male : .female
            let breed: String = isDog ? breedsDogs[i % breedsDogs.count] : breedsCats[i % breedsCats.count]
            let yearsOffset = -(1 + (i % 6))
            let birthDate: Date? = cal.date(byAdding: .year, value: yearsOffset, to: now)
            let color: String = isDog ? dogColors[i % dogColors.count] : catColors[i % catColors.count]
            
            let pet = Pet(
                name: name,
                species: species,
                breed: breed,
                birthDate: birthDate,
                sex: sex,
                color: color
            )
            
            // Opcional: icono como "foto"
            if i % 2 == 0,
               let img = UIImage(systemName: "pawprint.fill"),
               let data = img.pngData() {
                pet.photoData = data
            }
            
            ctx.insert(pet)
            result.append(pet)
            
            // Sembrar algunos eventos para que aparezcan tarjetas
            if withEvents {
                switch i % 4 {
                case 0:
                    let v = Vaccine(
                        date: now.addingTimeInterval(Double(2 + i) * 24 * 3600),
                        pet: pet,
                        vaccineName: "Rabia (dosis 1/3)"
                    )
                    ctx.insert(v)
                case 1:
                    let m = Medication(
                        date: now.addingTimeInterval(Double(1 + i) * 24 * 3600),
                        pet: pet,
                        name: "Amoxicilina",
                        dosage: "250 mg",
                        frequency: "cada 8 h"
                    )
                    ctx.insert(m)
                case 2:
                    let d = Deworming(
                        date: now.addingTimeInterval(Double(5 + i) * 24 * 3600),
                        pet: pet,
                        notes: "Tableta mensual"
                    )
                    ctx.insert(d)
                default:
                    let g = Grooming(
                        date: now.addingTimeInterval(Double(3 + i) * 24 * 3600),
                        pet: pet,
                        location: "Pet Spa",
                        notes: "Baño y corte"
                    )
                    ctx.insert(g)
                }
                // Además, insertar eventos pasados para que “últimos” tenga sentido
                let pastVac = Vaccine(date: now.addingTimeInterval(-20 * 24 * 3600),
                                      pet: pet, vaccineName: "Moquillo")
                let pastDew = Deworming(date: now.addingTimeInterval(-35 * 24 * 3600),
                                        pet: pet, notes: "Pipeta externa")
                let w = WeightEntry(date: now.addingTimeInterval(-3 * 24 * 3600),
                                    pet: pet, weightKg: isDog ? 22.8 : 4.2)
                ctx.insert(pastVac)
                ctx.insert(pastDew)
                ctx.insert(w)
            }
        }
        try? ctx.save()
        return result
    }
}

#Preview("Lista – Vacío") {
    let container = PetsListPreviewData.makeContainer()
    // No insertamos mascotas: muestra estado vacío
    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es")) // asegura español en previews
}

#Preview("Lista – 1 mascota") {
    let container = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 1, in: container, withEvents: true)
    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Lista – 2 mascotas") {
    let container = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 2, in: container, withEvents: true)
    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Lista – 3 mascotas") {
    let container = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 3, in: container, withEvents: true)
    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Lista – 5 (detalladas)") {
    let container = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 5, in: container, withEvents: true)
    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Lista – varias") {
    let container = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 8, in: container, withEvents: true)
    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}
