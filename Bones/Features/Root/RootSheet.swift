import Foundation

enum RootSheet: Identifiable {
    case record(RecordRequest)
    case newPet
    case editPet(Pet)
    case settings

    var id: String {
        switch self {
        case .record(let request): "record-\(request.id)"
        case .newPet:              "newPet"
        case .editPet(let pet):    "editPet-\(pet.id)"
        case .settings:            "settings"
        }
    }
}
