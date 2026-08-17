import SwiftData
import XCTest
@testable import AdventureBuddy

@MainActor
final class MilestoneEvaluatorTests: XCTestCase {
    func testFirstActivityMilestonesUseActivityTypeNotWinter() throws {
        let harness = try JournalHarness.makeContext()
        let walkDate = JournalHarness.date(year: 2026, month: 3, day: 2)
        let hikeDate = JournalHarness.date(year: 2026, month: 4, day: 8)
        let parkDate = JournalHarness.date(year: 2026, month: 5, day: 1)
        let beachDate = JournalHarness.date(year: 2026, month: 6, day: 12)
        let tripDate = JournalHarness.date(year: 2026, month: 7, day: 4)
        _ = JournalHarness.outing(place: "Loop", activity: .walk, date: walkDate, dog: harness.dog, in: harness.context)
        _ = JournalHarness.outing(place: "Peak", activity: .hike, date: hikeDate, dog: harness.dog, in: harness.context)
        _ = JournalHarness.outing(place: "Green", activity: .park, date: parkDate, dog: harness.dog, in: harness.context)
        _ = JournalHarness.outing(place: "Shore", activity: .beach, date: beachDate, dog: harness.dog, in: harness.context)
        _ = JournalHarness.outing(place: "Cabin", activity: .trip, date: tripDate, dog: harness.dog, in: harness.context)
        try harness.context.save()

        let earned = MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context)
        let ids = Set(earned.map(\.catalogID))
        XCTAssertEqual(
            ids,
            [
                MilestoneEvaluator.firstWalkID,
                MilestoneEvaluator.firstHikeID,
                MilestoneEvaluator.firstParkID,
                MilestoneEvaluator.firstBeachID,
                MilestoneEvaluator.firstTripID
            ]
        )
        XCTAssertEqual(dateEarned(MilestoneEvaluator.firstWalkID, dog: harness.dog), walkDate)
        XCTAssertEqual(dateEarned(MilestoneEvaluator.firstHikeID, dog: harness.dog), hikeDate)
        XCTAssertFalse(ids.contains(MilestoneEvaluator.firstSnowID))
    }

    func testTenOutingsUsesTenthDateAndDoesNotUnEarn() throws {
        let harness = try JournalHarness.makeContext()
        for day in 1...9 {
            _ = JournalHarness.outing(
                place: "Spot \(day)",
                date: JournalHarness.date(year: 2026, month: 3, day: day),
                dog: harness.dog,
                in: harness.context
            )
        }
        try harness.context.save()
        XCTAssertTrue(MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context).allSatisfy {
            $0.catalogID != MilestoneEvaluator.tenOutingsID
        })

        let tenthDate = JournalHarness.date(year: 2026, month: 3, day: 10)
        _ = JournalHarness.outing(place: "Spot 10", date: tenthDate, dog: harness.dog, in: harness.context)
        try harness.context.save()

        let newly = MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context)
        XCTAssertTrue(newly.contains { $0.catalogID == MilestoneEvaluator.tenOutingsID })
        XCTAssertEqual(dateEarned(MilestoneEvaluator.tenOutingsID, dog: harness.dog), tenthDate)

        let again = MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context)
        XCTAssertFalse(again.contains { $0.catalogID == MilestoneEvaluator.tenOutingsID })
        XCTAssertEqual(dateEarned(MilestoneEvaluator.tenOutingsID, dog: harness.dog), tenthDate)
    }

    func testTenPlacesUsesTrimmedLowercasedNames() throws {
        let harness = try JournalHarness.makeContext()
        let names = [
            "Eagle Peak",
            "  eagle peak ",
            "EAGLE PEAK",
            "River",
            "Park",
            "Beach",
            "Meadow",
            "Lake",
            "Ridge",
            "Trail",
            "Grove",
            "Point"
        ]
        for (index, name) in names.enumerated() {
            _ = JournalHarness.outing(
                place: name,
                date: JournalHarness.date(year: 2026, month: 2, day: index + 1),
                dog: harness.dog,
                in: harness.context
            )
        }
        try harness.context.save()

        let earned = MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context)
        XCTAssertTrue(earned.contains { $0.catalogID == MilestoneEvaluator.tenPlacesID })
        XCTAssertEqual(
            dateEarned(MilestoneEvaluator.tenPlacesID, dog: harness.dog),
            JournalHarness.date(year: 2026, month: 2, day: 12)
        )
    }

    func testFirstSnowIsKeywordOnlyNotWinterCalendar() throws {
        let harness = try JournalHarness.makeContext()
        let januaryWalk = JournalHarness.outing(
            place: "Tampa Bay",
            activity: .walk,
            date: JournalHarness.date(year: 2026, month: 1, day: 12),
            notes: "Warm loop by the water.",
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        XCTAssertFalse(MilestoneEvaluator.isSnowOuting(januaryWalk))
        let winterPass = MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context)
        XCTAssertFalse(winterPass.contains { $0.catalogID == MilestoneEvaluator.firstSnowID })
        XCTAssertNil(dateEarned(MilestoneEvaluator.firstSnowID, dog: harness.dog))

        let snowDate = JournalHarness.date(year: 2026, month: 7, day: 2)
        let snowy = JournalHarness.outing(
            place: "Sierra",
            activity: .hike,
            date: snowDate,
            notes: "First powder of the trip.",
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        XCTAssertTrue(MilestoneEvaluator.isSnowOuting(snowy))
        let snowPass = MilestoneEvaluator.evaluate(dog: harness.dog, in: harness.context)
        XCTAssertTrue(snowPass.contains { $0.catalogID == MilestoneEvaluator.firstSnowID })
        XCTAssertEqual(dateEarned(MilestoneEvaluator.firstSnowID, dog: harness.dog), snowDate)
    }

    func testSeedDoesNotDuplicateCatalogIDs() throws {
        let harness = try JournalHarness.makeContext()
        MilestoneCatalog.seed(into: harness.context, dog: harness.dog)
        MilestoneCatalog.seed(into: harness.context, dog: harness.dog)
        try harness.context.save()

        let milestones = ((try? harness.context.fetch(FetchDescriptor<Milestone>())) ?? [])
            .filter { $0.dog?.persistentModelID == harness.dog.persistentModelID }
        XCTAssertEqual(milestones.count, MilestoneCatalog.items.count)
        XCTAssertEqual(Set(milestones.map(\.catalogID)).count, MilestoneCatalog.items.count)
    }

    private func dateEarned(_ catalogID: String, dog: Dog) -> Date? {
        dog.milestones.first { $0.catalogID == catalogID }?.dateEarned
    }
}
