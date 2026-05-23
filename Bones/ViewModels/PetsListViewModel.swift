import Observation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class PetsListViewModel {
    private(set) var pets: [Pet] = []
    private var context: ModelContext

    init(context: ModelContext) {
        self.context = context
        fetchPets()
    }

    func updateContext(_ newContext: ModelContext) {
        context = newContext
        fetchPets()
    }

    func fetchPets() {
        pets = (try? context.fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    func addPet(name: String) throws {
        context.insert(Pet(name: name))
        try context.save()
        fetchPets()
    }

    func delete(at offsets: IndexSet) throws {
        for index in offsets { context.delete(pets[index]) }
        try context.save()
        fetchPets()
    }
}
