import Foundation
import SwiftData

enum MilestoneCatalog {
    static let items: [(catalogID: String, name: String, details: String, iconName: String)] = [
        (
            "first-hike",
            "First Hike",
            "Share your first hike together.",
            "figure.hiking"
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

    static func seed(into context: ModelContext, dog: Dog) {
        for item in items {
            let milestone = Milestone(
                catalogID: item.catalogID,
                name: item.name,
                details: item.details,
                iconName: item.iconName,
                dog: dog
            )
            context.insert(milestone)
        }
    }
}
