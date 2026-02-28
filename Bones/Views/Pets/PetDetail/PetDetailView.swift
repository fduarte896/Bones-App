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
    @State private var selectedTab: DetailTab = .upcoming

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingRemoveAlert = false
    @State private var isPresentingEdit = false
    
    // Animación de la barra de tabs
    @Namespace private var tabNamespace
    
    // Estado del subsegmento de Salud (elevado desde PetHealthTab)
    @State private var healthSegment: PetHealthTab.HealthSegment = .vaccines

    @AppStorage("didSeedDewormingDemo") private var didSeedDewormingDemo: Bool = false

    // Inicializador para inyectar el ViewModel
    init(pet: Pet) {
        self.pet = pet
        // Break up the expression to help the type-checker
        let id: UUID = pet.id
        let vm = PetDetailViewModel(petID: id)
        _viewModel = StateObject(wrappedValue: vm)   // aún sin contexto
    }
    
    var body: some View {
        VStack(spacing: 0) {

            // ---------- Cabecera ----------
            HStack(alignment: .top, spacing: 16) {
                // Foto (círculo o rectángulo redondeado)
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
                    .frame(width: 120, height: 120)        // tamaño fijo
                    .clipShape(Circle())                   // cambia a RoundedRectangle si prefieres
                    .contentShape(Rectangle())             // para gestos
                    
                    // Botón editar
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
                
                // Datos a la derecha
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

            
            // ---------- Picker de tabs (chips ancho completo + animación) ----------
            HStack(spacing: 8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.subheadline)
                            .minimumScaleFactor(0.85)
                            .lineLimit(1)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .background(
                                ZStack {
                                    // Fondo base
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                    // Fondo seleccionado animado
                                    if selectedTab == tab {
                                        Capsule()
                                            .fill(Color.accentColor)
                                            .matchedGeometryEffect(id: "tabSelection", in: tabNamespace)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

            
            // ---------- Contenido ----------
            Group {
                switch selectedTab {
                case .upcoming:
                    PetUpcomingEventsTab(viewModel: viewModel)
                case .health:
                    PetHealthTab(viewModel: viewModel, segment: $healthSegment)   // Vacunas + Desparasitación + Medicamentos
                case .grooming:
                    PetGroomingTab(viewModel: viewModel)
                case .weight:
                    PetWeightTab(pet: pet, viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    pet.photoData = data
                    try? context.save()
                    selectedItem = nil           // ← resetea para permitir nueva selección
                }
            }
        }

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
                    // Decidir initialKind y isDewormingInitial según la ubicación actual
                    let (initialKind, isDewormingInitial): (EventKind, Bool) = {
                        if selectedTab == .health {
                            switch healthSegment {
                            case .vaccines:
                                return (.vaccine, false)
                            case .deworm:
                                return (.medication, true)
                            case .medications:
                                return (.medication, false)
                            }
                        } else {
                            // Fallback a comportamiento anterior por pestaña general
                            switch selectedTab {
                            case .grooming: return (.grooming, false)
                            case .weight:   return (.weight, false)
                            case .health, .upcoming:
                                return (.medication, false)
                            }
                        }
                    }()
                    // DEBUG: log de intención calculada
                    print("[QuickAdd] Intent from tab=\(selectedTab) segment=\(healthSegment) → kind=\(initialKind) deworm=\(isDewormingInitial)")
                    // Abrimos la hoja con un item identificable (evita condiciones de carrera)
                    quickAddConfig = QuickAddConfig(kind: initialKind, isDeworming: isDewormingInitial)
                } label: {
                    Label("Nuevo evento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $quickAddConfig, onDismiss: {
            viewModel.fetchEvents()          // refresca la lista al volver
        }) { config in
            EventQuickAddSheet(pet: pet,
                               initialKind: config.kind,
                               isDewormingInitial: config.isDeworming)
            .onAppear {
                print("[QuickAdd] Sheet onAppear with intent kind=\(config.kind) deworm=\(config.isDeworming)")
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditPetSheet(pet: pet)
        }

        // Inyectamos el context real en el ViewModel al aparecer y sembramos demo si es necesario
        .onAppear {
            viewModel.inject(context: context)
            seedDewormingIfNeeded()
        }
        // DEBUG: trazas de navegación entre tabs/subtabs
        .onChange(of: selectedTab) { old, new in
            print("[QuickAdd] selectedTab \(old) → \(new)")
        }
        .onChange(of: healthSegment) { old, new in
            print("[QuickAdd] healthSegment \(old) → \(new)")
        }
    }
    
    // QuickAdd: modelo identificable para .sheet(item:)
    struct QuickAddConfig: Identifiable, Equatable {
        let id = UUID()
        let kind: EventKind
        let isDeworming: Bool
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
    case upcoming, health, grooming, weight
    
    var title: String {
        switch self {
        case .upcoming:     return "Próximos"
        case .health:       return "Salud"
        case .grooming:     return "Grooming"
        case .weight:       return "Peso"
        }
    }
}

extension DetailTab {
    var defaultEventKind: EventKind {
        switch self {
        case .health:       return .vaccine       // Quick Add desde Salud: por defecto vacuna
        case .grooming:     return .grooming
        case .weight:       return .weight
        default:            return .medication   // Upcoming u otra
        }
    }
}

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

// MARK: - Preview

#Preview {
    // 1) Container en memoria con el esquema necesario
    let schema = Schema([
        Pet.self,
        Medication.self,
        Vaccine.self,
        Deworming.self,
        Grooming.self,
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

