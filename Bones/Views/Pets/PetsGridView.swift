////
////  PetsGridView.swift
////  Bones
////
////  Created by Felipe Duarte on 23/07/25.
////
//import SwiftUI
//import SwiftData
//
//struct PetsGridView: View {
//    @Environment(\.modelContext) private var context
//    @Query(sort: \Pet.name) private var pets: [Pet]            // SwiftData fetch
//    
//    @State private var isPresentingAdd = false
//    @State private var petToEdit: Pet?
//    
//    // Grid 2-4 col según ancho
//    private let columns = [ GridItem(.adaptive(minimum: 150), spacing: 16) ]
//    
//    var body: some View {
//        NavigationStack {
//            if pets.isEmpty {
//                ContentUnavailableView("Sin mascotas", systemImage: "pawprint")
//            } else {
//                ScrollView {
//                    LazyVGrid(columns: columns, spacing: 16) {
//                        ForEach(pets) { pet in
//                            NavigationLink {
//                                PetDetailView(pet: pet)
//                            } label: {
//                                PetCardView(
//                                    pet: pet,
//                                    nextEventDate: nextEvent(for: pet)
//                                )
//                            }
//                            .contextMenu {
//                                Button("Editar", systemImage: "pencil") {
//                                    petToEdit = pet
//                                    isPresentingAdd = true   // reutiliza hoja
//                                }
//                                Divider()
//                                Button("Eliminar", systemImage: "trash", role: .destructive) {
//                                    context.delete(pet)
//                                    try? context.save()
//                                }
//                            }
//                        }
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.top, 20)
//                }
//                .navigationTitle("Mascotas")
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Button {
//                            isPresentingAdd = true
//                            petToEdit = nil
//                        } label: {
//                            Image(systemName: "plus")
//                        }
//                    }
//                }
//                .sheet(isPresented: $isPresentingAdd) {
//                    if let pet = petToEdit {
//                        EditPetSheet(pet: pet)          // hoja de edición (simple)
//                    } else {
//                        AddPetSheet()                   // hoja de creación que ya hiciste
//                    }
//                }
//            }
//            }
//           
//
//    }
//    
//    // ---------- Helper ----------
//    private func nextEvent(for pet: Pet) -> Date? {
//        // Trae 1° evento futuro (puedes optimizar con ViewModel si prefieres)
//        let descriptors = [
//            FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.date)]),
//            FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date)]),
//            FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date)]),
//            FetchDescriptor<Grooming>(sortBy: [SortDescriptor(\.date)])
//        ] as [Any]
//        return descriptors.compactMap { desc in
//            (try? context.fetch(desc))?
//                .first { $0.pet?.id == pet.id && $0.date >= Date() }?.date
//        }.min()
//    }
//}
//
//
//#Preview {
//    PetsGridView()
//}
