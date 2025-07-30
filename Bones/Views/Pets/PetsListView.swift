//
//  PetsListView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData
import PhotosUI          // si muestras miniaturas

struct PetsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var pets: [Pet]   // alfabético
    
    @State private var isPresentingAdd = false
    @State private var petToEdit: Pet?   // nuevo state
    
    // 2 columnas en iPhone, 3-4 en iPad/landscape
    private let columns = [ GridItem(.adaptive(minimum: 150), spacing: 16) ]
    
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

            
            else {
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
    
    // --- helper para próximo evento ---
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


}

#Preview {
    PetsListView()
}
