import Foundation
import SwiftData

@Model
final class Milestone {
    var catalogID: String
    var name: String
    var details: String
    var iconName: String
    var dateEarned: Date?
    var dog: Dog?

    var isEarned: Bool { dateEarned != nil }

    init(
        catalogID: String,
        name: String,
        details: String,
        iconName: String,
        dateEarned: Date? = nil,
        dog: Dog? = nil
    ) {
        self.catalogID = catalogID
        self.name = name
        self.details = details
        self.iconName = iconName
        self.dateEarned = dateEarned
        self.dog = dog
    }
}
