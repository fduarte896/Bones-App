// OpenAppIntent.swift
import AppIntents

struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir Bones"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        // No hace nada más; el sistema abrirá la app gracias a openAppWhenRun
        .result()
    }
}
