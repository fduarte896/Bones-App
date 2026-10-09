import Foundation

/// Destinos a los que se navega desde la ficha.
enum CareRoute: Hashable {
    case care(petID: UUID, kind: CareKind)
    case weight(petID: UUID)

    var petID: UUID {
        switch self {
        case .care(let petID, _), .weight(let petID): petID
        }
    }
}
