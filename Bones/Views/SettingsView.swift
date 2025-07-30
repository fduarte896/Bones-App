//
//  SettingView.swift
//  Bones
//
//  Created by Felipe Duarte on 16/07/25.
//

import SwiftUI
import Foundation

//  SettingsView.swift
import SwiftUI

// MARK: - Enumeraciones
enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var label: String {
        switch self {
        case .system: "Sistema"
        case .light:  "Claro"
        case .dark:   "Oscuro"
        }
    }
}

struct SettingsView: View {
    // Persistencia en UserDefaults mediante @AppStorage
    @AppStorage("themeMode") private var theme: ThemeMode = .system
    @AppStorage("defaultLeadTime") private var leadTime: Int = 60   // minutos
    
    // Calcula versión y build
    private var versionString: String {
        let dict = Bundle.main.infoDictionary
        let ver = dict?["CFBundleShortVersionString"] as? String ?? "–"
        let build = dict?["CFBundleVersion"] as? String ?? "–"
        return "\(ver) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // ---------- General ----------
                Section("General") {
                    Picker("Tema", selection: $theme) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
                
                // ---------- Notificaciones ----------
                Section("Notificaciones") {
                    Picker("Recordatorio previo", selection: $leadTime) {
                        Text("Al momento").tag(0)
                        Text("15 min").tag(15)
                        Text("1 hora").tag(60)
                        Text("1 día").tag(1440)
                    }
                }
                
                // ---------- Acerca de ----------
                Section {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ajustes")
        }
        // Aplica el tema al resto de la app
        .preferredColorScheme(
            theme == .system ? nil :
            (theme == .light ? .light : .dark)
        )
    }
}



#Preview {
    SettingsView()
}
