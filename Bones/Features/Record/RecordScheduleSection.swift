import SwiftUI

/// Cuándo se aplicó y cada cuánto se repite. De ahí sale la próxima fecha.
struct RecordScheduleSection: View {
    @Binding var draft: RecordDraft

    private var repeatOptions: [RepeatRule] {
        guard let current = draft.repeatRule, !RepeatRule.presets.contains(current) else {
            return RepeatRule.presets
        }
        return RepeatRule.presets + [current]
    }

    private var footer: String? {
        if draft.isPlanned() {
            "Todavía no llega esa fecha: queda programada y te avisaremos antes."
        } else if let next = draft.nextDate() {
            "Próxima vez: \(BonesFormat.day(next))."
        } else {
            nil
        }
    }

    var body: some View {
        Section {
            DatePicker("Fecha", selection: $draft.date, displayedComponents: .date)
            Picker("Repetir", selection: $draft.repeatRule) {
                Text("No repetir").tag(RepeatRule?.none)
                ForEach(repeatOptions) { rule in
                    Text(rule.label).tag(RepeatRule?.some(rule))
                }
            }
        } footer: {
            if let footer {
                Text(footer)
                    .contentTransition(.numericText())
                    .animation(.default, value: footer)
            }
        }
    }
}
