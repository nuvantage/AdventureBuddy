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
}
