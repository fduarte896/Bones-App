import Foundation

/// Los datos de una mascota mientras se editan, para que "Cancelar" de verdad cancele.
struct PetDraft: Equatable {
    var name = ""
    var species: Species = .perro
    var sex: Sex = .unknown
    var breed = ""
    var hasBirthDate = false
    var birthDate: Date = .now
    var photoData: Data?

    var isValid: Bool { name.nilIfBlank != nil }

    init() {}

    init(pet: Pet) {
        name = pet.name
        species = pet.species
        sex = pet.sex
        breed = pet.breed ?? ""
        hasBirthDate = pet.birthDate != nil
        birthDate = pet.birthDate ?? .now
        photoData = pet.photoData
    }

    func apply(to pet: Pet) {
        pet.name = name.nilIfBlank ?? pet.name
        pet.species = species
        pet.sex = sex
        pet.breed = breed.nilIfBlank
        pet.birthDate = hasBirthDate ? birthDate : nil
        pet.photoData = photoData
    }
}
