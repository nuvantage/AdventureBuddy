import Foundation
import SwiftData

enum PreviewSupport {
    @MainActor
    static func container(includeSampleOutings: Bool = true) -> ModelContainer {
        let schema = Schema([Dog.self, Outing.self, Milestone.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let dog = Dog(name: "Scout", breed: "Australian Shepherd", birthdate: sampleBirthday)
        context.insert(dog)
        MilestoneCatalog.seed(into: context, dog: dog)

        if includeSampleOutings {
            for outing in sampleOutings(for: dog) {
                context.insert(outing)
            }
            MilestoneEvaluator.evaluate(dog: dog, in: context)
        }

        return container
    }

    private static var sampleBirthday: Date {
        date(year: 2023, month: 5, day: 12)
    }

    static func sampleOutings(for dog: Dog) -> [Outing] {
        [
            Outing(
                date: date(year: 2026, month: 8, day: 2, hour: 8, minute: 15),
                latitude: 38.5916,
                longitude: -121.5044,
                locationName: "Riverside Trail",
                activityType: "walk",
                notes: "Morning loop along the river. Scout found every stick.",
                dog: dog
            ),
            Outing(
                date: date(year: 2026, month: 8, day: 10, hour: 9, minute: 40),
                latitude: 38.7999,
                longitude: -120.0324,
                locationName: "Eagle Peak",
                activityType: "hike",
                notes: "First real climb together. Lots of water stops, even more tail wags.",
                dog: dog
            ),
            Outing(
                date: date(year: 2026, month: 8, day: 14, hour: 16, minute: 20),
                latitude: 38.5383,
                longitude: -121.5036,
                locationName: "William Land Park",
                activityType: "park",
                notes: "Shade, squirrels, and a long flop in the grass.",
                dog: dog
            )
        ]
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date.distantPast
    }
}
