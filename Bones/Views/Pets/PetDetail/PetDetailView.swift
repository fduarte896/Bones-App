//
//  PetDetailView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData
import PhotosUI


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
    @State private var showingQuickAdd = false

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingRemoveAlert = false
    @State private var isPresentingEdit = false

    
    // Inicializador para inyectar el ViewModel
    init(pet: Pet) {
        self.pet = pet
        _viewModel = StateObject(
            wrappedValue: PetDetailViewModel(petID: pet.id)   // aún sin contexto
        )
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

            
            // ---------- Picker de tabs ----------
            Picker("Sección", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // ---------- Contenido ----------
            Group {
                switch selectedTab {
                case .upcoming:
                    PetUpcomingEventsTab(viewModel: viewModel)
                case .medications:
                    PetMedicationsTab(viewModel: viewModel)
                case .vaccines:
                    PetVaccinesTab(viewModel: viewModel)
                case .deworming:
                    PetDewormingTab(viewModel: viewModel)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Editar", systemImage: "pencil") { isPresentingEdit = true }
                    Divider()
                    // Botón + existente
                    Button { showingQuickAdd = true } label: {
                        Label("Nuevo evento", systemImage: "plus")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }

        }
        .sheet(isPresented: $showingQuickAdd, onDismiss: {
            viewModel.fetchEvents()          // refresca la lista al volver
        }) {
            EventQuickAddSheet(pet: pet,
                               initialKind: selectedTab.defaultEventKind
            )
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditPetSheet(pet: pet)
        }
        


        // Inyectamos el context real en el ViewModel al aparecer
        .onAppear { viewModel.inject(context: context) }
    }
}

// MARK: - Enum de tabs
enum DetailTab: CaseIterable {
    case upcoming, medications, vaccines, deworming, grooming, weight
    
    var title: String {
        switch self {
        case .upcoming:     return "Próximos"
        case .medications:  return "Medicamentos"
        case .vaccines:     return "Vacunas"
        case .deworming:    return "Desparasitación"
        case .grooming:     return "Grooming"
        case .weight:       return "Peso"

        }
    }
}

extension DetailTab {
    var defaultEventKind: EventKind {
        switch self {
        case .medications:  return .medication
        case .vaccines:     return .vaccine
        case .grooming:     return .grooming
        case .deworming:    return .deworming
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
    // 1. Creamos una instancia de Pet con datos de ejemplo
    let samplePet = Pet(
        name: "Loki",
        species: .dog,
        breed: "Husky",
        birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
        sex: .male,
        color: "White"
    )
    PetDetailView(pet: samplePet)
   
}
