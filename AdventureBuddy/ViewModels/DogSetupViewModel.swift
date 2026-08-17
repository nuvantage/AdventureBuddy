import Foundation
import Observation

@MainActor
@Observable
final class DogSetupViewModel {
    var name = ""
    var breed = ""
    var photoData: Data?

    var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBreed: String? {
        let value = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
