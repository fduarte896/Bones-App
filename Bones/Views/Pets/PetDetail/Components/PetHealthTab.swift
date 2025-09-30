import SwiftUI

struct PetHealthTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    
    private enum HealthSegment: String, CaseIterable, Identifiable {
        case vaccines = "Vacunas"
        case deworm   = "Desparasitación"
        var id: Self { self }
    }
    
    @State private var segment: HealthSegment = .vaccines
    
    var body: some View {
        VStack(spacing: 0) {
            // Selector interno
            Picker("", selection: $segment) {
                ForEach(HealthSegment.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
            
            // Contenido
            switch segment {
            case .vaccines:
                PetVaccinesTab(viewModel: viewModel)
            case .deworm:
                PetDewormingTab(viewModel: viewModel)
            }
        }
    }
}