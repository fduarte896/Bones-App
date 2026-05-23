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
    @AppStorage(AppStorageKey.didChooseDemoPet)     private var didChooseDemoPet: Bool = false
    @AppStorage(AppStorageKey.demoGuideStep)        private var demoGuideStep: Int = 0
    @AppStorage(AppStorageKey.didCompleteDemoGuide) private var didCompleteDemoGuide: Bool = false
    
    @State private var isPresentingAdd = false
    @State private var petToEdit: Pet?   // nuevo state
    @State private var navigateToPetDetail: Pet?
    
    // 2 columnas en iPhone, 3-4 en iPad/landscape (modo compacto)
    private let columns = [ GridItem(.adaptive(minimum: 150), spacing: 16) ]
    // Modo detallado (tarjetas más anchas/altas)
    private let detailedColumns = [ GridItem(.adaptive(minimum: 220), spacing: 16) ]
    
    var body: some View {
        NavigationStack {
            Group {
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
                SinglePetDashboardView(
                    pet: pet,
                    demoGuideStep: $demoGuideStep,
                    didCompleteDemoGuide: $didCompleteDemoGuide
                )
                    .navigationTitle("Resumen")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                if demoGuideStep == DemoGuideStep.addPet.rawValue {
                                    demoGuideStep = DemoGuideStep.detail.rawValue
                                }
                                isPresentingAdd = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .demoGuideAnchor(.addPetButton)
                        }
                    }
                    .sheet(isPresented: $isPresentingAdd) {
                        AddPetSheet()
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
                                    lastWeight: lastWeight(for: pet),
                                    lastVaccine: lastVaccine(for: pet),
                                    lastDeworming: lastDeworming(for: pet)
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
            .navigationDestination(item: $navigateToPetDetail) { pet in
                PetDetailView(pet: pet)
            }
        }
        .overlayPreferenceValue(DemoGuideAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if shouldShowDemoGuide,
                   let step = DemoGuideStep(rawValue: demoGuideStep) {
                    switch step {
                    case .summary:
                        if let anchor = anchors[.dashboardHeader] {
                            DemoGuideOverlay(
                                targetRect: proxy[anchor],
                                title: "Resumen de Marcos",
                                message: "Aquí ves lo esencial de su salud y próximos cuidados.",
                                primaryActionTitle: "Siguiente",
                                onPrimaryAction: { demoGuideStep = DemoGuideStep.addPet.rawValue },
                                onSkip: skipDemoGuide,
                                presentationStyle: .centered
                            )
                        }
                    case .addPet:
                        if let anchor = anchors[.addPetButton] {
                            DemoGuideOverlay(
                                targetRect: proxy[anchor],
                                title: "Añade otra mascota",
                                message: "Usa este + para crear un nuevo perfil.",
                                primaryActionTitle: "Siguiente",
                                onPrimaryAction: {
                                    demoGuideStep = DemoGuideStep.upcoming.rawValue
                                    openDetailIfPossible()
                                },
                                onSkip: skipDemoGuide,
                                presentationStyle: .centered
                            )
                        }
                    case .detail:
                        if let anchor = anchors[.detailButton] {
                            DemoGuideOverlay(
                                targetRect: proxy[anchor],
                                title: "Ver detalle",
                                message: "Entra al perfil completo para ver pestañas y eventos.",
                                primaryActionTitle: "Siguiente",
                                onPrimaryAction: {
                                    demoGuideStep = DemoGuideStep.upcoming.rawValue
                                    openDetailIfPossible()
                                },
                                onSkip: skipDemoGuide,
                                presentationStyle: .centered
                            )
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var shouldShowDemoGuide: Bool {
        didChooseDemoPet && !didCompleteDemoGuide && demoGuideStep <= DemoGuideStep.detail.rawValue
    }

    private func skipDemoGuide() {
        didCompleteDemoGuide = true
    }

    private func openDetailIfPossible() {
        if let pet = pets.first {
            navigateToPetDetail = pet
        }
    }
    
    // --- helpers para tarjetas ---
    private func nextEvent(for pet: Pet) -> Date? {
        let now = Date()

        // 1. Vacunas
        let vacDate = (try? context.fetch(
            FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\Vaccine.date)])
        ))?
        .first { $0.pet?.id == pet.id && $0.date >= now }?
        .date

        // 2. Desparasitación
        let dewDate = (try? context.fetch(
            FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\Deworming.date)])
        ))?
        .first { $0.pet?.id == pet.id && $0.date >= now }?
        .date

        // Devuelve la fecha más cercana (mínima no-nula)
        return [vacDate, dewDate]
            .compactMap { $0 }
            .min()
    }
    
    private func lastWeight(for pet: Pet) -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }

    private func lastVaccine(for pet: Pet) -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now && $0.isCompleted }
    }

    private func lastDeworming(for pet: Pet) -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now && $0.isCompleted }
    }
}

// MARK: - Solicitud de nuevo evento para sheets

private struct QuickAddRequest: Identifiable {
    let id = UUID()
    let kind: EventKind
}

private struct DetailNavTarget: Identifiable, Hashable {
    let id = UUID()
    let tab: DetailTab
}

// MARK: - Dashboard para una sola mascota

private struct SinglePetDashboardView: View {
    @Environment(\.modelContext) private var context
    let pet: Pet
    @Binding var demoGuideStep: Int
    @Binding var didCompleteDemoGuide: Bool

    @State private var detailDestination: DetailNavTarget?
    @State private var isPresentingEdit = false
    @State private var showingDeleteAlert = false
    
    // Layout de tarjetas: dos columnas fijas
    private let twoCols = [ GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12) ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                
                // Fila 1: Peso actual (izq) + Próxima vacuna (der)
                LazyVGrid(columns: twoCols, alignment: .leading, spacing: 12) {
                    currentWeightCard
                    nextVaccineCard
                }
                .padding(.horizontal)

                // Fila 2: Última vacuna (izq) + Próxima desparasitación (der)
                LazyVGrid(columns: twoCols, alignment: .leading, spacing: 12) {
                    lastVaccineCard
                    nextDewormingCard
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
            .demoGuideAnchor(.dashboardHeader)
        }
        .navigationDestination(item: $detailDestination) { target in
            PetDetailView(pet: pet, initialTab: target.tab)
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

    // Cabecera con foto + datos + acciones
    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            // Foto — toca para ir a tab Próximos
            NavigationLink {
                PetDetailView(pet: pet, initialTab: .upcoming)
            } label: {
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
            }
            .buttonStyle(.plain)
            .demoGuideAnchor(.detailButton)
            .simultaneousGesture(TapGesture().onEnded {
                if demoGuideStep == DemoGuideStep.detail.rawValue {
                    demoGuideStep = DemoGuideStep.upcoming.rawValue
                }
            })

            // Datos básicos
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

                Button {
                    isPresentingEdit = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Tarjetas (nueva estructura)

    private var nextVaccineCard: some View {
        let next = nextVaccine()
        return InfoCard(
            icon: "syringe",
            title: "Próxima vacuna",
            primary: next.map { formatDateTime($0.date) } ?? "Sin programar",
            secondary: next?.vaccineName
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .vaccines)
        }
    }

    private var lastVaccineCard: some View {
        let last = lastVaccine()
        return InfoCard(
            icon: "syringe",
            title: "Última \nvacuna",
            primary: last.map { formatDate($0.date) } ?? "Nunca",
            secondary: last.map { DoseSeries.splitDoseBase(from: $0.vaccineName) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .vaccines)
        }
    }

    private var nextDewormingCard: some View {
        let next = nextDeworming()
        return InfoCard(
            icon: "ladybug.fill",
            title: "Próxima desparasitación",
            primary: next.map { formatDateTime($0.date) } ?? "Sin programar",
            secondary: next?.notes
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .deworming)
        }
    }

    private var lastDewormingCard: some View {
        let last = lastDeworming()
        return InfoCard(
            icon: "ladybug.fill",
            title: "Última desparasitación",
            primary: last.map { formatDateTime($0.date) } ?? "Nunca",
            secondary: last.map { esRelativeFormatter.localizedString(for: $0.date, relativeTo: Date()) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .deworming)
        }
    }

    private var currentWeightCard: some View {
        let last = lastWeight()
        return InfoCard(
            icon: "scalemass",
            title: "Peso \nactual",
            primary: last.map { String(format: "%.1f kg", $0.weightKg) } ?? "—",
            secondary: last.map { formatDate($0.date) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .weight)
        }
    }

    // MARK: - Fetch helpers SIN #Predicate (evita errores de macro)
    private func nextVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }
    }
    
    private func nextDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }
    }
    
    private func lastVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now && $0.isCompleted }
    }
    
    private func lastDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now && $0.isCompleted }
    }
    
    private func lastWeight() -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }
    
    // MARK: - Delete
    private func deletePet() {
        // 1) Cancelar notificaciones de todos sus eventos
        let vacs = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []

        for e in vacs where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
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

    @State private var detailDestination: DetailNavTarget?
    @State private var isPresentingEdit = false
    @State private var showingDeleteAlert = false

    // Dos columnas fijas para las filas
    private let twoCols = [ GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12) ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cabecera
            HStack(alignment: .center, spacing: 16) {
                // Foto — toca para ir a tab Próximos
                NavigationLink {
                    PetDetailView(pet: pet, initialTab: .upcoming)
                } label: {
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
                }
                .buttonStyle(.plain)

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

                    Button {
                        isPresentingEdit = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
            }
            
            // Fila 1: Peso actual (izq) + Próxima vacuna (der)
            LazyVGrid(columns: twoCols, alignment: .leading, spacing: 12) {
                currentWeightCard
                nextVaccineCard
            }

            // Fila 2: Última vacuna (izq) + Próxima desparasitación (der)
            LazyVGrid(columns: twoCols, alignment: .leading, spacing: 12) {
                lastVaccineCard
                nextDewormingCard
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
        .navigationDestination(item: $detailDestination) { target in
            PetDetailView(pet: pet, initialTab: target.tab)
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

    // MARK: - Tarjetas
    private var nextVaccineCard: some View {
        let next = nextVaccine()
        return InfoCard(
            icon: "syringe",
            title: "Próxima vacuna",
            primary: next?.date.formatted(date: .abbreviated, time: .shortened) ?? "Sin programar",
            secondary: next?.vaccineName
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .vaccines)
        }
    }

    private var lastVaccineCard: some View {
        let last = lastVaccine()
        return InfoCard(
            icon: "syringe",
            title: "Última \nvacuna",
            primary: last?.date.formatted(date: .abbreviated, time: .omitted) ?? "Nunca",
            secondary: last.map { DoseSeries.splitDoseBase(from: $0.vaccineName) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .vaccines)
        }
    }

    private var nextDewormingCard: some View {
        let next = nextDeworming()
        return InfoCard(
            icon: "ladybug.fill",
            title: "Próxima desparasitación",
            primary: next?.date.formatted(date: .abbreviated, time: .shortened) ?? "Sin programar",
            secondary: next?.notes
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .deworming)
        }
    }

    private var lastDewormingCard: some View {
        let last = lastDeworming()
        return InfoCard(
            icon: "ladybug.fill",
            title: "Última desparasitación",
            primary: last?.date.formatted(date: .abbreviated, time: .shortened) ?? "Nunca",
            secondary: last.map { esRelativeFormatter.localizedString(for: $0.date, relativeTo: Date()) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .deworming)
        }
    }

    private var currentWeightCard: some View {
        let last = lastWeight()
        return InfoCard(
            icon: "scalemass",
            title: "Peso \nactual",
            primary: last.map { String(format: "%.1f kg", $0.weightKg) } ?? "—",
            secondary: last.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            detailDestination = DetailNavTarget(tab: .weight)
        }
    }

    // MARK: - Fetch helpers (evita macro #Predicate)
    private func nextVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }
    }
    
    private func nextDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .forward)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date >= now && !$0.isCompleted }
    }
    
    private func lastVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now && $0.isCompleted }
    }
    
    private func lastDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.date <= now && $0.isCompleted }
    }
    
    private func lastWeight() -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }
    
    // MARK: - Delete
    private func deletePet() {
        // 1) Cancelar notificaciones de todos sus eventos
        let vacs = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []

        for e in vacs where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
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
    let lastVaccine: Vaccine?
    let lastDeworming: Deworming?
    
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
                Text(nextEventDate.map { formatDateTime($0) } ?? "Sin eventos próximos")
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
                    Text(formatDate(w.date))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                }
            }
            .font(.caption)

            // Última vacuna
            if let lastVaccine {
                HStack(spacing: 8) {
                    Image(systemName: "syringe")
                        .foregroundStyle(.secondary)
                    Text(DoseSeries.splitDoseBase(from: lastVaccine.vaccineName))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            // Última desparasitación
            if let lastDeworming {
                HStack(spacing: 8) {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(.secondary)
                    Text(formatDateTime(lastDeworming.date))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
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
// MARK: - Previews

private enum PetsListPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Vaccine.self,
            Deworming.self,
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
                    let d2 = Deworming(
                        date: now.addingTimeInterval(Double(1 + i) * 24 * 3600),
                        pet: pet,
                        notes: "Pipeta mensual"
                    )
                    ctx.insert(d2)
                case 2:
                    let d = Deworming(
                        date: now.addingTimeInterval(Double(5 + i) * 24 * 3600),
                        pet: pet,
                        notes: "Tableta mensual"
                    )
                    ctx.insert(d)
                default:
                    break
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

#Preview("Demo Guide – Resumen") {
    let container = PetsListPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let pet = Pet(name: "Marcos", species: .perro, breed: "Demo Breed", sex: .male)
    if let img = UIImage(named: "MarcosPhoto"), let data = img.jpegData(compressionQuality: 0.9) {
        pet.photoData = data
    }
    ctx.insert(pet)
    try? ctx.save()

    let defaults = UserDefaults.standard
    defaults.set(true, forKey: "didChooseDemoPet")
    defaults.set(false, forKey: "didCompleteDemoGuide")
    defaults.set(DemoGuideStep.summary.rawValue, forKey: "demoGuideStep")

    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Demo Guide – + Mascota") {
    let container = PetsListPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let pet = Pet(name: "Marcos", species: .perro, breed: "Demo Breed", sex: .male)
    if let img = UIImage(named: "MarcosPhoto"), let data = img.jpegData(compressionQuality: 0.9) {
        pet.photoData = data
    }
    ctx.insert(pet)
    try? ctx.save()

    let defaults = UserDefaults.standard
    defaults.set(true, forKey: "didChooseDemoPet")
    defaults.set(false, forKey: "didCompleteDemoGuide")
    defaults.set(DemoGuideStep.addPet.rawValue, forKey: "demoGuideStep")

    return PetsListView()
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Demo Guide – Ver Detalle") {
    let container = PetsListPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let pet = Pet(name: "Marcos", species: .perro, breed: "Demo Breed", sex: .male)
    if let img = UIImage(named: "MarcosPhoto"), let data = img.jpegData(compressionQuality: 0.9) {
        pet.photoData = data
    }
    ctx.insert(pet)
    try? ctx.save()

    let defaults = UserDefaults.standard
    defaults.set(true, forKey: "didChooseDemoPet")
    defaults.set(false, forKey: "didCompleteDemoGuide")
    defaults.set(DemoGuideStep.detail.rawValue, forKey: "demoGuideStep")

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
