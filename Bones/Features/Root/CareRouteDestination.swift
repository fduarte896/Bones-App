import SwiftUI

struct CareRouteDestination: View {
    let route: CareRoute
    let pets: [Pet]
    let zoom: Namespace.ID
    let onSaved: () -> Void

    var body: some View {
        if let pet = pets.first(where: { $0.id == route.petID }) {
            Group {
                switch route {
                case .care(_, let kind):
                    CareHistoryView(pet: pet, kind: kind, onSaved: onSaved)
                case .weight:
                    WeightHistoryView(pet: pet, onSaved: onSaved)
                }
            }
            .navigationTransition(.zoom(sourceID: route, in: zoom))
        } else {
            ContentUnavailableView("Esta mascota ya no existe", systemImage: "pawprint")
        }
    }
}
