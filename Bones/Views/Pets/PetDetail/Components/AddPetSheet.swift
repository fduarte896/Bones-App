//
//  AddPetSheet.swift
//  Bones
//
//  Created by Felipe Duarte on 16/07/25.
//
import SwiftUI
import PhotosUI
import SwiftData      // para insertar directamente el nuevo Pet

struct AddPetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context     // contenedor SwiftData
    
    // MARK: – Estado del formulario
    @State private var name = ""
    @State private var species: Species = .dog        // enum existente (.dog / .cat)
    @State private var sex: Sex = .male               // enum (.male / .female)
    @State private var birthDate = Date()                // se ajustará con DatePicker
    @State private var breed = ""
    @State private var color = ""
    
    // Foto
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    
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
                            if let data = photoData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, height: 120)
                            }
                        }
                        Spacer()
                    }
                }
                
                // ---------- Datos básicos ----------
                Section("Datos básicos") {
                    TextField("Nombre", text: $name)
                        .autocorrectionDisabled()
                    
                    Picker("Especie", selection: $species) {
                        Text("Perro").tag(Species.dog)
                        Text("Gato").tag(Species.cat)
                    }
                    Picker("Sexo", selection: $sex) {
                        Text("Macho").tag(Sex.male)
                        Text("Hembra").tag(Sex.female)
                    }
                    DatePicker("Fecha de nacimiento",
                               selection: $birthDate,
                               displayedComponents: .date)
                }
                
                // ---------- Información opcional ----------
                Section("Información opcional") {
                    TextField("Raza", text: $breed)
                    TextField("Color", text: $color)
                }
            }
            .navigationTitle("Nueva mascota")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { savePet() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: dismiss.callAsFunction)
                }
            }
            // Carga la imagen seleccionada
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }
    
    // MARK: – Guardar en SwiftData
    private func savePet() {
        let newPet = Pet(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthDate: birthDate,
            sex: sex,
            color: color.isEmpty ? nil : color
        )
        newPet.photoData = photoData      // puede ser nil
        
        context.insert(newPet)
        try? context.save()
        dismiss()
    }
}


//#Preview {
//    AddPetSheet()
//}
