import Foundation
import SwiftData

@Model
final class Dog {
    var name: String
    var breed: String?
    var birthdate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Outing.dog)
    var outings: [Outing]

    @Relationship(deleteRule: .cascade, inverse: \Milestone.dog)
    var milestones: [Milestone]

    init(
        name: String,
        breed: String? = nil,
        birthdate: Date? = nil,
        photoData: Data? = nil
    ) {
        self.name = name
        self.breed = breed
        self.birthdate = birthdate
        self.photoData = photoData
        self.createdAt = Date()
        self.outings = []
        self.milestones = []
    }

    var ageDescription: String? {
        guard let birthdate else { return nil }
        return DogAgeFormatter.string(from: birthdate)
    }
}

enum DogAgeFormatter {
    static func string(from birthdate: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: birthdate, to: now)

        if let years = components.year, years >= 1 {
            return years == 1 ? "1 year" : "\(years) years"
        }
        if let months = components.month, months >= 1 {
            return months == 1 ? "1 month" : "\(months) months"
        }

        let days = max(components.day ?? 0, 0)
        if days < 1 {
            return "Newborn"
        }
        if days < 7 {
            return days == 1 ? "1 day" : "\(days) days"
        }

        let weeks = max(days / 7, 1)
        return weeks == 1 ? "1 week" : "\(weeks) weeks"
    }
}
