import Foundation
import Observation

@MainActor
@Observable
final class DogSetupViewModel {
    var name = ""
    var breed = ""
    var photoData: Data?
    var hasBirthdate = false
    var birthdate = DogSetupViewModel.defaultBirthdate

    init(dog: Dog? = nil) {
        self.name = dog?.name ?? ""
        self.breed = dog?.breed ?? ""
        self.photoData = dog?.photoData
        if let existing = dog?.birthdate {
            self.hasBirthdate = true
            self.birthdate = existing
        }
    }

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

    var selectedBirthdate: Date? {
        hasBirthdate ? Calendar.current.startOfDay(for: birthdate) : nil
    }

    var birthdayRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let thirtyYearsAgo = calendar.date(byAdding: .year, value: -30, to: Date()) ?? Date.distantPast
        let earliest = min(thirtyYearsAgo, birthdate)
        let latest = max(Date(), birthdate)
        return earliest...latest
    }

    private static var defaultBirthdate: Date {
        Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
    }
}
