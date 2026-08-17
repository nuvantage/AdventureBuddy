import SwiftData
import XCTest
@testable import AdventureBuddy

@MainActor
final class CurrentDogTests: XCTestCase {
    func testResolvePicksOldestCompanionAndNeverInserts() throws {
        let harness = try JournalHarness.makeContext()
        XCTAssertEqual(CurrentDog.resolve(from: [harness.dog])?.persistentModelID, harness.dog.persistentModelID)
        XCTAssertEqual(CurrentDog.resolve(in: harness.context)?.persistentModelID, harness.dog.persistentModelID)

        let later = Dog(name: "Later")
        later.createdAt = harness.dog.createdAt.addingTimeInterval(60)
        harness.context.insert(later)
        try harness.context.save()

        XCTAssertEqual(
            CurrentDog.resolve(from: [later, harness.dog])?.persistentModelID,
            harness.dog.persistentModelID
        )
        XCTAssertEqual(CurrentDog.resolve(in: harness.context)?.persistentModelID, harness.dog.persistentModelID)
        XCTAssertEqual(((try? harness.context.fetch(FetchDescriptor<Dog>())) ?? []).count, 2)
    }

    func testOutingsBelongOnlyToResolvedCompanion() throws {
        let harness = try JournalHarness.makeContext()
        let other = Dog(name: "Other")
        harness.context.insert(other)
        let mine = JournalHarness.outing(
            place: "River",
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        _ = JournalHarness.outing(
            place: "Elsewhere",
            date: JournalHarness.date(year: 2026, month: 8, day: 2),
            dog: other,
            in: harness.context
        )
        try harness.context.save()

        let fetched = (try? harness.context.fetch(FetchDescriptor<Outing>())) ?? []
        let visible = CurrentDog.outings(fetched, for: CurrentDog.resolve(in: harness.context))
        XCTAssertEqual(visible.map(\.persistentModelID), [mine.persistentModelID])
        XCTAssertTrue(CurrentDog.outings(fetched, for: nil).isEmpty)
    }
}
