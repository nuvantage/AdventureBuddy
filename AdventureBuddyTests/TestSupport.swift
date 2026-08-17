import CoreLocation
import Foundation
import SwiftData
@testable import AdventureBuddy

/// In-memory SwiftData helpers for logic tests. These tests are not a device pass.
enum JournalHarness {
    @MainActor
    static func makeContext() throws -> (container: ModelContainer, context: ModelContext, dog: Dog) {
        let schema = Schema([Dog.self, Outing.self, Milestone.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let dog = Dog(name: "Scout")
        context.insert(dog)
        MilestoneCatalog.seed(into: context, dog: dog)
        try context.save()
        return (container, context, dog)
    }

    static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? Date.distantPast
    }

    @MainActor
    static func outing(
        place: String,
        activity: Outing.Activity = .walk,
        date: Date,
        latitude: Double = 38.5816,
        longitude: Double = -121.4944,
        notes: String? = nil,
        dog: Dog,
        in context: ModelContext
    ) -> Outing {
        let outing = Outing(
            date: date,
            latitude: latitude,
            longitude: longitude,
            locationName: place,
            activityType: activity.rawValue,
            notes: notes,
            dog: dog
        )
        context.insert(outing)
        return outing
    }

    static func offset(
        from latitude: Double,
        _ longitude: Double,
        northMeters: Double,
        eastMeters: Double = 0
    ) -> (latitude: Double, longitude: Double) {
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = max(metersPerDegreeLatitude * cos(latitude * .pi / 180), 1)
        return (
            latitude + northMeters / metersPerDegreeLatitude,
            longitude + eastMeters / metersPerDegreeLongitude
        )
    }
}
