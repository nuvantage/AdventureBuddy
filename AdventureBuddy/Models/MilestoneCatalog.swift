import Foundation
import SwiftData

enum MilestoneCatalog {
    static let items: [(catalogID: String, name: String, details: String, iconName: String)] = [
        (
            "first-walk",
            "First Walk",
            "Share your first walk together.",
            "figure.walk"
        ),
        (
            "first-hike",
            "First Hike",
            "Share your first hike together.",
            "figure.hiking"
        ),
        (
            "first-park",
            "First Park Day",
            "Log a park outing together.",
            "leaf.fill"
        ),
        (
            "first-beach",
            "First Beach Day",
            "Make it to the beach together.",
            "water.waves"
        ),
        (
            "first-trip",
            "First Trip",
            "Take a trip outing together.",
            "suitcase.fill"
        ),
        (
            "ten-outings",
            "10 Outings",
            "Log 10 adventures together.",
            "10.circle.fill"
        ),
        (
            "ten-places",
            "10 Places Visited",
            "Log outings at 10 different places.",
            "map.fill"
        ),
        (
            "first-snow",
            "First Snow Outing",
            "Head out together after the first snow.",
            "snowflake"
        )
    ]

    /// Inserts any catalog rows the dog is missing. Matches `catalogID` so
    /// existing dogs pick up new milestones without duplicates. Never clears
    /// `dateEarned`.
    static func seed(into context: ModelContext, dog: Dog) {
        let dogID = dog.persistentModelID
        let fetched = ((try? context.fetch(FetchDescriptor<Milestone>())) ?? [])
            .filter { $0.dog?.persistentModelID == dogID }
        var existingIDs = Set((fetched + dog.milestones).map(\.catalogID))

        for item in items {
            guard !existingIDs.contains(item.catalogID) else { continue }
            let milestone = Milestone(
                catalogID: item.catalogID,
                name: item.name,
                details: item.details,
                iconName: item.iconName,
                dog: dog
            )
            context.insert(milestone)
            existingIDs.insert(item.catalogID)
        }
    }
}
