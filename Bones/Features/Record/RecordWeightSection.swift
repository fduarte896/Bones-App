import SwiftUI

struct RecordWeightSection: View {
    @Binding var draft: RecordDraft
    @FocusState private var isFocused: Bool

    var body: some View {
        Section {
            LabeledContent("Peso") {
                HStack(spacing: 4) {
                    TextField("0", value: $draft.weightKg, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($isFocused)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }
            }
            DatePicker("Fecha", selection: $draft.date, in: ...Date.now, displayedComponents: .date)
        }
        .onAppear { isFocused = draft.weightKg == nil }
    }
}
