import SwiftData
import XCTest
@testable import AdventureBuddy

final class JournalStatsTests: XCTestCase {
    @MainActor
    func testDistinctPlacesTrimAndLowercase() throws {
        let harness = try JournalHarness.makeContext()
        _ = JournalHarness.outing(
            place: "Eagle Peak",
            activity: .hike,
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        _ = JournalHarness.outing(
            place: "  eagle peak ",
            activity: .walk,
            date: JournalHarness.date(year: 2026, month: 8, day: 2),
            dog: harness.dog,
            in: harness.context
        )
        _ = JournalHarness.outing(
            place: "Riverside Trail",
            activity: .walk,
            date: JournalHarness.date(year: 2026, month: 8, day: 3),
            dog: harness.dog,
            in: harness.context
        )
        _ = JournalHarness.outing(
            place: "   ",
            activity: .park,
            date: JournalHarness.date(year: 2026, month: 8, day: 4),
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        let outings = ((try? harness.context.fetch(FetchDescriptor<Outing>())) ?? [])
        let stats = JournalStats.from(outings: outings)
        XCTAssertEqual(stats.outingCount, 4)
        XCTAssertEqual(stats.distinctPlaceCount, 2)
        XCTAssertEqual(stats.firstOutingDate, JournalHarness.date(year: 2026, month: 8, day: 1))
        XCTAssertEqual(stats.lastOutingDate, JournalHarness.date(year: 2026, month: 8, day: 4))
        XCTAssertEqual(stats.activityCounts.first { $0.activity == .walk }?.count, 2)
        XCTAssertEqual(stats.activityCounts.first { $0.activity == .hike }?.count, 1)
        XCTAssertEqual(stats.activityCounts.first { $0.activity == .park }?.count, 1)
    }

    func testEmptyJournalHasNoOutings() {
        let stats = JournalStats.from(outings: [])
        XCTAssertFalse(stats.hasOutings)
        XCTAssertEqual(stats.distinctPlaceCount, 0)
        XCTAssertNil(stats.firstOutingDate)
    }
}
