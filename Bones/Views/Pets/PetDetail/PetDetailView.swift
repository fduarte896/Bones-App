//
//  PetDetailView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation


// MARK: - Detalle de la mascota
struct PetDetailView: View {
    // Entrada
    let pet: Pet
    
    // Contexto de SwiftData disponible para toda la vista
    @Environment(\.modelContext) private var context
    
    // ViewModel – se crea con el id de la mascota
    @StateObject private var viewModel: PetDetailViewModel
    
    // Picker interno
    @State private var selectedTab: DetailTab

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingRemoveAlert = false
    @State private var isPresentingEdit = false

    // Animación de la barra de tabs
    @Namespace private var tabNamespace

    @AppStorage(AppStorageKey.didSeedDewormingDemo)  private var didSeedDewormingDemo: Bool = false
    @AppStorage(AppStorageKey.didChooseDemoPet)      private var didChooseDemoPet: Bool = false
    @AppStorage(AppStorageKey.demoGuideStep)         private var demoGuideStep: Int = 0
    @AppStorage(AppStorageKey.didCompleteDemoGuide)  private var didCompleteDemoGuide: Bool = false

    init(pet: Pet, initialTab: DetailTab = .upcoming) {
        self.pet = pet
        let id: UUID = pet.id
        let vm = PetDetailViewModel(petID: id)
        _viewModel = StateObject(wrappedValue: vm)
        _selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        coreView
            .overlayPreferenceValue(DemoGuideAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    demoGuideOverlay(anchors: anchors, proxy: proxy)
                }
            }
    }

    @ViewBuilder
    private var coreView: some View {
        petStack
            .alert("¿Eliminar foto?", isPresented: $showingRemoveAlert) {
                Button("Eliminar", role: .destructive) {
                    pet.photoData = nil
                    try? context.save()
                }
                Button("Cancelar", role: .cancel) { }
            }
            .navigationTitle(pet.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Editar", systemImage: "pencil") { isPresentingEdit = true }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        let initialKind: EventKind = {
                            switch selectedTab {
                            case .vaccines:  return .vaccine
                            case .deworming: return .deworming
                            case .weight:    return .weight
                            case .upcoming:  return .vaccine
                            }
                        }()
                        quickAddConfig = QuickAddConfig(kind: initialKind)
                    } label: {
                        Label("Nuevo evento", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $quickAddConfig, onDismiss: { viewModel.fetchEvents() }) { config in
                EventQuickAddSheet(pet: pet, initialKind: config.kind)
                    .onAppear {
                        print("[QuickAdd] Sheet onAppear with intent kind=\(config.kind)")
                    }
            }
            .sheet(isPresented: $isPresentingEdit) {
                EditPetSheet(pet: pet)
            }
            .onAppear {
                viewModel.inject(context: context)
                seedDewormingIfNeeded()
            }
            .onChange(of: selectedTab) { old, new in
                print("[QuickAdd] selectedTab \(old) → \(new)")
            }
    }

    @ViewBuilder
    private var petStack: some View {
        VStack(spacing: 0) {

            // ---------- Cabecera ----------
            HStack(alignment: .top, spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let data = pet.photoData,
                           let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                                .padding(20)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .contentShape(Rectangle())

                    PhotosPicker(selection: $selectedItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 26))
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .onLongPressGesture { showingRemoveAlert = true }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.title2).bold()
                    HStack {
                        Text(pet.sex.rawValue.capitalized)
                        Text("|")
                        if let age = ageString(for: pet.birthDate) {
                            Text(age)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("\(pet.species.rawValue.capitalized) · \(pet.breed ?? "Sin raza")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let color = pet.color, !color.isEmpty {
                        Text("Color: \(color)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            // ---------- Picker de tabs ----------
            HStack(spacing: 8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

            // ---------- Contenido ----------
            Group {
                switch selectedTab {
                case .upcoming:
                    PetUpcomingEventsTab(viewModel: viewModel)
                case .vaccines:
                    PetVaccinesTab(viewModel: viewModel)
                case .deworming:
                    PetDewormingTab(viewModel: viewModel)
                case .weight:
                    PetWeightTab(pet: pet, viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        pet.photoData = data
                        try? context.save()
                        selectedItem = nil
                    }
                } catch {
                    print("Photo load failed: \(error)")
                }
            }
        }
        .onAppear {
            if shouldShowDemoGuideInDetail,
               demoGuideStep == DemoGuideStep.detail.rawValue {
                demoGuideStep = DemoGuideStep.upcoming.rawValue
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            guard shouldShowDemoGuideInDetail else { return }
            switch newTab {
            case .vaccines:
                if demoGuideStep == DemoGuideStep.upcoming.rawValue {
                    demoGuideStep = DemoGuideStep.health.rawValue
                }
            case .weight:
                if demoGuideStep == DemoGuideStep.health.rawValue {
                    demoGuideStep = DemoGuideStep.weight.rawValue
                }
            default:
                break
            }
        }
    }

    @ViewBuilder
    private func demoGuideOverlay(anchors: [DemoGuideAnchor: Anchor<CGRect>], proxy: GeometryProxy) -> some View {
        if shouldShowDemoGuideInDetail,
           let step = DemoGuideStep(rawValue: demoGuideStep) {
            switch step {
            case .upcoming:
                if let anchor = anchors[.tabUpcoming] {
                    DemoGuideOverlay(
                        targetRect: proxy[anchor],
                        title: "Próximos",
                        message: "Aquí aparecen eventos cercanos y vencidos.",
                        primaryActionTitle: "Siguiente",
                        onPrimaryAction: {
                            selectedTab = .vaccines
                            demoGuideStep = DemoGuideStep.health.rawValue
                        },
                        onSkip: skipDemoGuide,
                        presentationStyle: .centered
                    )
                }
            case .health:
                if let anchor = anchors[.tabVaccines] {
                    DemoGuideOverlay(
                        targetRect: proxy[anchor],
                        title: "Vacunas",
                        message: "Historial de vacunas y próximas dosis de tu mascota.",
                        primaryActionTitle: "Siguiente",
                        onPrimaryAction: {
                            selectedTab = .weight
                            demoGuideStep = DemoGuideStep.weight.rawValue
                        },
                        onSkip: skipDemoGuide,
                        presentationStyle: .centered
                    )
                }
            case .weight:
                if let anchor = anchors[.tabWeight] {
                    DemoGuideOverlay(
                        targetRect: proxy[anchor],
                        title: "Peso",
                        message: "Historial y evolución del peso de tu mascota.",
                        primaryActionTitle: "Finalizar",
                        onPrimaryAction: finishDemoGuide,
                        onSkip: skipDemoGuide,
                        presentationStyle: .centered
                    )
                }
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func tabButton(for tab: DetailTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            tabButtonLabel(for: tab)
        }
        .buttonStyle(.plain)
        .demoGuideAnchor(guideAnchor(for: tab))
    }

    @ViewBuilder
    private func tabButtonLabel(for tab: DetailTab) -> some View {
        let isSelected = selectedTab == tab
        Text(tab.title)
            .font(.subheadline)
            .minimumScaleFactor(0.85)
            .lineLimit(1)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(tabBackground(isSelected: isSelected))
    }

    @ViewBuilder
    private func tabBackground(isSelected: Bool) -> some View {
        ZStack {
            Capsule().fill(Color(.systemGray5))
            if isSelected {
                Capsule()
                    .fill(Color.accentColor)
                    .matchedGeometryEffect(id: "tabSelection", in: tabNamespace)
            }
        }
    }

    private var shouldShowDemoGuideInDetail: Bool {
        didChooseDemoPet && !didCompleteDemoGuide && demoGuideStep >= DemoGuideStep.upcoming.rawValue
    }

    private func guideAnchor(for tab: DetailTab) -> DemoGuideAnchor {
        switch tab {
        case .upcoming:   return .tabUpcoming
        case .vaccines:   return .tabVaccines
        case .deworming:  return .tabDeworming
        case .weight:     return .tabWeight
        }
    }

    private func skipDemoGuide() {
        didCompleteDemoGuide = true
    }

    private func finishDemoGuide() {
        didCompleteDemoGuide = true
        demoGuideStep = DemoGuideStep.done.rawValue
    }
    
    // QuickAdd: modelo identificable para .sheet(item:)
    struct QuickAddConfig: Identifiable, Equatable {
        let id = UUID()
        let kind: EventKind
    }
    @State private var quickAddConfig: QuickAddConfig?
}

private extension PetDetailView {
    func seedDewormingIfNeeded() {
        guard !didSeedDewormingDemo else { return }

        // Global: si ya existen desparasitantes en la base, no sembrar
        let anyDeworming = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        if !anyDeworming.isEmpty {
            didSeedDewormingDemo = true
            return
        }
        
        // Sembrando para la mascota actualmente abierta en primer arranque global

        let cal = Calendar.current
        let now = Date()

        // Serie A: Drontal Plus — hoy + 15 días (2/2), luego refuerzo a 3 meses
        let seriesA = UUID()
        let a1 = Deworming(date: now,
                           pet: pet,
                           notes: "Drontal Plus (dosis 1/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        a1.isCompleted = true
        let a2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                           pet: pet,
                           notes: "Drontal Plus (dosis 2/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        let aBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                 pet: pet,
                                 notes: "Drontal Plus",
                                 prescriptionImageData: nil,
                                 seriesID: seriesA)

        // Serie B: Endogard — 2/2 con una vencida y una futura, y un refuerzo a 3 meses
        let seriesB = UUID()
        let b1 = Deworming(date: cal.date(byAdding: .day, value: -10, to: now)!,
                           pet: pet,
                           notes: "Endogard (dosis 1/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesB)
        let b2 = Deworming(date: cal.date(byAdding: .day, value: 5, to: now)!,
                           pet: pet,
                           notes: "Endogard (dosis 2/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesB)
        let bBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                 pet: pet,
                                 notes: "Endogard",
                                 prescriptionImageData: nil,
                                 seriesID: seriesB)

        // Serie C: Panacur — 3 días seguidos y repetir el ciclo a los 14 días
        let seriesC = UUID()
        let c1 = Deworming(date: cal.date(byAdding: .day, value: -1, to: now)!,
                           pet: pet,
                           notes: "Panacur (dosis 1/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesC)
        c1.isCompleted = true
        let c2 = Deworming(date: now,
                           pet: pet,
                           notes: "Panacur (dosis 2/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesC)
        let c3 = Deworming(date: cal.date(byAdding: .day, value: 1, to: now)!,
                           pet: pet,
                           notes: "Panacur (dosis 3/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesC)
        let cR1 = Deworming(date: cal.date(byAdding: .day, value: 14, to: now)!,
                            pet: pet,
                            notes: "Panacur (dosis 1/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesC)
        let cR2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                            pet: pet,
                            notes: "Panacur (dosis 2/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesC)
        let cR3 = Deworming(date: cal.date(byAdding: .day, value: 16, to: now)!,
                            pet: pet,
                            notes: "Panacur (dosis 3/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesC)

        // Insertar en contexto (evitando duplicados si ya hay datos)
        [a1, a2, aBooster,
         b1, b2, bBooster,
         c1, c2, c3, cR1, cR2, cR3].forEach { context.insert($0) }
        try? context.save()
        didSeedDewormingDemo = true
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// MARK: - Enum de tabs
enum DetailTab: CaseIterable {
    case upcoming, vaccines, deworming, weight

    var title: String {
        switch self {
        case .upcoming:   return "Próximos"
        case .vaccines:   return "Vacunas"
        case .deworming:  return "Parásitos"
        case .weight:     return "Peso"
        }
    }
}

extension DetailTab {
    var defaultEventKind: EventKind {
        switch self {
        case .vaccines:   return .vaccine
        case .deworming:  return .deworming
        case .weight:     return .weight
        case .upcoming:   return .vaccine
        }
    }
}

// MARK: - Preview

#Preview {
    // 1) Container en memoria con el esquema necesario
    let schema = Schema([
        Pet.self,
        Vaccine.self,
        Deworming.self,
        WeightEntry.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    let ctx = ModelContext(container)

    // 2) Mascota demo
    let samplePet = Pet(
        name: "Loki",
        species: .perro,
        breed: "Husky",
        birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
        sex: .male,
        color: "White"
    )
    ctx.insert(samplePet)

    // 3) Siembra de desparasitación (varios ejemplos)
    let cal = Calendar.current
    let now = Date()

    // Serie A: Drontal Plus — hoy + 15 días (2/2), luego refuerzo a 3 meses
    let seriesA = UUID()
    let a1 = Deworming(date: now,
                       pet: samplePet,
                       notes: "Drontal Plus (dosis 1/2)",
                       prescriptionImageData: nil,
                       seriesID: seriesA)
    a1.isCompleted = true
    let a2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                       pet: samplePet,
                       notes: "Drontal Plus (dosis 2/2)",
                       prescriptionImageData: nil,
                       seriesID: seriesA)
    let aBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                             pet: samplePet,
                             notes: "Drontal Plus",
                             prescriptionImageData: nil,
                             seriesID: seriesA)

    // Serie B: Endogard — 2/2 con una vencida y una futura, y un refuerzo a 3 meses
    let seriesB = UUID()
    let b1 = Deworming(date: cal.date(byAdding: .day, value: -10, to: now)!,
                       pet: samplePet,
                       notes: "Endogard (dosis 1/2)",
                       prescriptionImageData: nil,
                       seriesID: seriesB)
    // b1 queda pendiente para visualizar "Vencida"
    let b2 = Deworming(date: cal.date(byAdding: .day, value: 5, to: now)!,
                       pet: samplePet,
                       notes: "Endogard (dosis 2/2)",
                       prescriptionImageData: nil,
                       seriesID: seriesB)
    let bBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                             pet: samplePet,
                             notes: "Endogard",
                             prescriptionImageData: nil,
                             seriesID: seriesB)

    // Serie C: Panacur — 3 días seguidos y repetir el ciclo a los 14 días
    let seriesC = UUID()
    let c1 = Deworming(date: cal.date(byAdding: .day, value: -1, to: now)!,
                       pet: samplePet,
                       notes: "Panacur (dosis 1/3)",
                       prescriptionImageData: nil,
                       seriesID: seriesC)
    c1.isCompleted = true
    let c2 = Deworming(date: now,
                       pet: samplePet,
                       notes: "Panacur (dosis 2/3)",
                       prescriptionImageData: nil,
                       seriesID: seriesC)
    let c3 = Deworming(date: cal.date(byAdding: .day, value: 1, to: now)!,
                       pet: samplePet,
                       notes: "Panacur (dosis 3/3)",
                       prescriptionImageData: nil,
                       seriesID: seriesC)
    // Repetición del ciclo a los 14 días
    let cR1 = Deworming(date: cal.date(byAdding: .day, value: 14, to: now)!,
                        pet: samplePet,
                        notes: "Panacur (dosis 1/3)",
                        prescriptionImageData: nil,
                        seriesID: seriesC)
    let cR2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                        pet: samplePet,
                        notes: "Panacur (dosis 2/3)",
                        prescriptionImageData: nil,
                        seriesID: seriesC)
    let cR3 = Deworming(date: cal.date(byAdding: .day, value: 16, to: now)!,
                        pet: samplePet,
                        notes: "Panacur (dosis 3/3)",
                        prescriptionImageData: nil,
                        seriesID: seriesC)

    // Serie D: Milbemax — hoy y repetir cada 6 meses (ejemplo de recurrencia)
    let seriesD = UUID()
    let d1 = Deworming(date: cal.date(byAdding: .day, value: -30, to: now)!,
                       pet: samplePet,
                       notes: "Milbemax",
                       prescriptionImageData: nil,
                       seriesID: seriesD)
    d1.isCompleted = true
    let d2 = Deworming(date: now,
                       pet: samplePet,
                       notes: "Milbemax",
                       prescriptionImageData: nil,
                       seriesID: seriesD)
    let dNext = Deworming(date: cal.date(byAdding: .month, value: 6, to: now)!,
                          pet: samplePet,
                          notes: "Milbemax",
                          prescriptionImageData: nil,
                          seriesID: seriesD)

    // Insertar eventos en el contexto y guardar
    [a1, a2, aBooster,
     b1, b2, bBooster,
     c1, c2, c3, cR1, cR2, cR3,
     d1, d2, dNext].forEach { ctx.insert($0) }
    try? ctx.save()

    // 4) Render
    return PetDetailView(pet: samplePet)
        .modelContainer(container)
}

// MARK: - Demo Guide Previews

private enum PetDetailDemoGuidePreviewData {
    static func makeContainerAndPet() -> (ModelContainer, Pet) {
        let schema = Schema([
            Pet.self,
            Vaccine.self,
            Deworming.self,
            WeightEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)

        let pet = Pet(
            name: "Marcos",
            species: .perro,
            breed: "Demo Breed",
            birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
            sex: .male,
            color: "Blanco"
        )
        if let img = UIImage(named: "MarcosPhoto"), let data = img.jpegData(compressionQuality: 0.9) {
            pet.photoData = data
        }
        ctx.insert(pet)
        try? ctx.save()
        return (container, pet)
    }

    static func setGuide(step: DemoGuideStep) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "didChooseDemoPet")
        defaults.set(false, forKey: "didCompleteDemoGuide")
        defaults.set(step.rawValue, forKey: "demoGuideStep")
    }
}

#Preview("Demo Guide – Próximos") {
    let (container, pet) = PetDetailDemoGuidePreviewData.makeContainerAndPet()
    PetDetailDemoGuidePreviewData.setGuide(step: .upcoming)
    return NavigationStack {
        PetDetailView(pet: pet)
    }
    .modelContainer(container)
    .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Demo Guide – Salud") {
    let (container, pet) = PetDetailDemoGuidePreviewData.makeContainerAndPet()
    PetDetailDemoGuidePreviewData.setGuide(step: .health)
    return NavigationStack {
        PetDetailView(pet: pet)
    }
    .modelContainer(container)
    .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Demo Guide – Peso") {
    let (container, pet) = PetDetailDemoGuidePreviewData.makeContainerAndPet()
    PetDetailDemoGuidePreviewData.setGuide(step: .weight)
    return NavigationStack {
        PetDetailView(pet: pet)
    }
    .modelContainer(container)
    .environment(\.locale, Locale(identifier: "es"))
}
