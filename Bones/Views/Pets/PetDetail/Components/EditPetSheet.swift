//
//  editPetSheet.swift
//  Bones
//
//  Created by Felipe Duarte on 23/07/25.
//

import SwiftUI
import PhotosUI
import SwiftData

struct EditPetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var pet: Pet           // ⬅️  se pasa la instancia existente
    
    // Picker de foto
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            Form {
                // ---------- Foto ----------
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            Group {
                                if let data = pet.photoData,
                                   let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                } else {
                                    Image(systemName: "photo")
                                        .resizable().scaledToFit()
                                        .foregroundStyle(.secondary)
                                        .padding(24)
                                }
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        }
                        Spacer()
                    }
                    Button("Eliminar foto", role: .destructive) {
                        pet.photoData = nil
                    }
                    .disabled(pet.photoData == nil)
                }
                
                // ---------- Datos básicos ----------
                Section("Datos básicos") {
                    TextField("Nombre", text: $pet.name)
                        .autocorrectionDisabled()
                    
                    Picker("Especie", selection: $pet.species) {
                        Text("Perro").tag(Species.dog)
                        Text("Gato").tag(Species.cat)
                    }
                    Picker("Sexo", selection: $pet.sex) {
                        Text("Macho").tag(Sex.male)
                        Text("Hembra").tag(Sex.female)
                    }
                    DatePicker("Fecha de nacimiento",
                               selection: Binding($pet.birthDate, replacingNilWith: Date()),
                               displayedComponents: .date)
                }
                
                // ---------- Información opcional ----------
                Section("Información opcional") {
                    TextField("Raza", text: Binding($pet.breed, replacingNilWith: ""))
                    TextField("Color", text: Binding($pet.color, replacingNilWith: ""))
                }
            }
            .navigationTitle("Editar mascota")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        try? context.save()
                        dismiss()
                    }
                    .disabled(pet.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: dismiss.callAsFunction)
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        pet.photoData = data
                    }
                }
            }
        }
    }
}

extension Binding {
    init(_ source: Binding<Value?>, replacingNilWith defaultValue: Value) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}
