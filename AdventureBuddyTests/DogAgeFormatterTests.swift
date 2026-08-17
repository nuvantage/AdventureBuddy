import XCTest
@testable import AdventureBuddy

final class DogAgeFormatterTests: XCTestCase {
    func testAgeBuckets() {
        let calendar = Calendar.current
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 8
        parts.day = 17
        parts.hour = 12
        let now = calendar.date(from: parts)!

        XCTAssertEqual(
            DogAgeFormatter.string(from: now, now: now),
            "Newborn"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: days(-1, from: now, calendar: calendar), now: now),
            "1 day"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: days(-3, from: now, calendar: calendar), now: now),
            "3 days"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: days(-7, from: now, calendar: calendar), now: now),
            "1 week"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: days(-14, from: now, calendar: calendar), now: now),
            "2 weeks"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: months(-1, from: now, calendar: calendar), now: now),
            "1 month"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: months(-5, from: now, calendar: calendar), now: now),
            "5 months"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: years(-1, from: now, calendar: calendar), now: now),
            "1 year"
        )
        XCTAssertEqual(
            DogAgeFormatter.string(from: years(-3, from: now, calendar: calendar), now: now),
            "3 years"
        )
    }

    private func days(_ value: Int, from date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: value, to: date)!
    }

    private func months(_ value: Int, from date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: value, to: date)!
    }

    private func years(_ value: Int, from date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .year, value: value, to: date)!
    }
}
