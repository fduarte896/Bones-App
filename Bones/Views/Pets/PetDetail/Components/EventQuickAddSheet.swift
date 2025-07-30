//
//  EventQuickAddSheet.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData

// MARK: - Enum de tipos disponibles
enum EventKind: String, CaseIterable, Identifiable {
    case medication  = "Medicamento"
    case vaccine     = "Vacuna"
    case deworming   = "Desparasitación"
    case grooming    = "Grooming"
    case weight      = "Peso"
    
    var id: String { rawValue }
    
    /// Icono SF Symbol para el picker
    var icon: String {
        switch self {
        case .medication: return "pills.fill"
        case .vaccine:    return "syringe"
        case .deworming:  return "bandage.fill"
        case .grooming:   return "scissors"
        case .weight:     return "scalemass"
        }
    }
}

struct EventQuickAddSheet: View {
    
    // MARK: – Dependencias
    var pet: Pet
    let initialKind: EventKind
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // MARK: – Estado del formulario
    @State private var kind: EventKind
    @State private var title: String = ""
    
    // Medicamento
    @State private var dosage: String = ""
    @State private var frequency: String = ""
    
    // Vacuna
    @State private var manufacturer: String = ""
    
    // Grooming
    @State private var location: String = ""
    
    // Peso
    @State private var weightKg: String = ""
    
    // Fecha común
    @State private var eventDate: Date = .now.addingTimeInterval(60 * 60)
    
    init(pet: Pet, initialKind: EventKind = .medication) {
        self.pet = pet
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }
    
    // MARK: – Cuerpo
    var body: some View {
        NavigationStack {
            Form {
                // ---------- Tipo ----------
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(EventKind.allCases) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // ---------- Campos comunes ----------
                Section("Detalles") {
                    switch kind {
                    case .medication:
                        TextField("Nombre del medicamento", text: $title).autocorrectionDisabled()
                        TextField("Dosis (ej. 10 mg)", text: $dosage)
                        TextField("Frecuencia (ej. BID)", text: $frequency)
                            
                    case .vaccine:
                        TextField("Nombre de la vacuna", text: $title).autocorrectionDisabled()
                        TextField("Fabricante", text: $manufacturer).autocorrectionDisabled()
                            
                    case .deworming:
                        TextField("Nombre del desparasitante", text: $title).autocorrectionDisabled()
                        TextField("Descripción", text: $manufacturer)
                            
                    case .grooming:
                        TextField("Descripción", text: $title)
                        TextField("Lugar", text: $location)
                            
                    case .weight:
                        TextField("Peso (kg)", text: $weightKg)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // ---------- Fecha ----------
                Section("Fecha") {
                    DatePicker("Recordatorio",
                               selection: $eventDate,
                               displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Nuevo evento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveEvent() }
                        .disabled(titleRequired && title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // Algunos tipos requieren título explícito
    private var titleRequired: Bool {
        kind != .weight
    }
    
    // MARK: – Guardar y notificar
    private func saveEvent() {
        do {
            switch kind {
            case .medication:
                let m = Medication(
                    date: eventDate,
                    pet: pet,
                    name: title,
                    dosage: dosage,
                    frequency: frequency
                )
                context.insert(m)
                schedule(id: m.id, title: "Medicamento", body: "\(pet.name) – \(title)")
                
            case .vaccine:
                let v = Vaccine(
                    date: eventDate,
                    pet: pet,
                    vaccineName: title,
                    manufacturer: manufacturer
                )
                context.insert(v)
                schedule(id: v.id, title: "Vacuna", body: "\(pet.name) – \(title)")
                
            case .deworming:
                let d = Deworming(date: eventDate, pet: pet, notes: title)
                context.insert(d)
                schedule(id: d.id, title: "Desparasitación", body: "\(pet.name)")
                
            case .grooming:
                let g = Grooming(date: eventDate, pet: pet, location: location, notes: title)
                context.insert(g)
                schedule(id: g.id, title: "Grooming", body: "\(pet.name)")
                
            case .weight:
                let value = Double(weightKg) ?? 0
                let w = WeightEntry(date: eventDate, pet: pet, weightKg: value)
                context.insert(w)
                // Sin notificación para peso por defecto
            }
            
            try context.save()
            // QuickAddSheet   ➜ después de try context.save()
            NotificationCenter.default.post(name: .eventsDidChange, object: nil)

            dismiss()
        } catch {
            print("⚠️ Error al guardar: \(error)")
        }
    }
    
    private func schedule(id: UUID, title: String, body: String) {
        NotificationManager.shared.scheduleNotification(
            id: id,
            title: title,
            body: body,
            fireDate: eventDate,
            advance: 0                  // exacto a la hora elegida
        )
        print("🔔 Notificación programada (\(title))")
    }
}
