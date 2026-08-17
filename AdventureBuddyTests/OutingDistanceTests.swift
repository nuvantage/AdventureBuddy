import CoreLocation
import SwiftData
import XCTest
@testable import AdventureBuddy

@MainActor
final class OutingDistanceTests: XCTestCase {
    func testHidesDistanceUnderTenMeters() throws {
        let harness = try JournalHarness.makeContext()
        let origin = JournalHarness.outing(
            place: "River",
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        let nearby = JournalHarness.offset(from: origin.latitude, origin.longitude, northMeters: 5)
        let next = JournalHarness.outing(
            place: "Bend",
            date: JournalHarness.date(year: 2026, month: 8, day: 2),
            latitude: nearby.latitude,
            longitude: nearby.longitude,
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        let actual = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
        XCTAssertLessThan(actual, OutingDistance.minimumDisplayableMeters)
        XCTAssertNil(OutingDistance.metersToNextOuting(from: origin, among: [origin, next]))
        XCTAssertNil(OutingDistance.label(from: origin, among: [origin, next], usesMetric: true, compact: true))
    }

    func testUsesNextOutingInTimeNotLaterPins() throws {
        let harness = try JournalHarness.makeContext()
        let first = JournalHarness.outing(
            place: "Dawn",
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        let thirdPlace = JournalHarness.offset(from: first.latitude, first.longitude, northMeters: 2_000, eastMeters: 500)
        let third = JournalHarness.outing(
            place: "Ridge",
            date: JournalHarness.date(year: 2026, month: 8, day: 10),
            latitude: thirdPlace.latitude,
            longitude: thirdPlace.longitude,
            dog: harness.dog,
            in: harness.context
        )
        let secondPlace = JournalHarness.offset(from: first.latitude, first.longitude, northMeters: 80)
        let second = JournalHarness.outing(
            place: "Meadow",
            date: JournalHarness.date(year: 2026, month: 8, day: 3),
            latitude: secondPlace.latitude,
            longitude: secondPlace.longitude,
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        let outings = [first, second, third]
        XCTAssertEqual(
            OutingDistance.nextOuting(after: first, among: outings)?.persistentModelID,
            second.persistentModelID
        )
        let meters = OutingDistance.metersToNextOuting(from: first, among: outings)
        XCTAssertEqual(meters ?? 0, 80, accuracy: 8)
        XCTAssertNil(OutingDistance.nextOuting(after: third, among: outings))
        XCTAssertNil(OutingDistance.metersToNextOuting(from: third, among: outings))
    }

    func testHidesWhenCurrentOrNextPinIsInvalid() throws {
        let harness = try JournalHarness.makeContext()
        let valid = JournalHarness.outing(
            place: "Trail",
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        let invalidNext = JournalHarness.outing(
            place: "Missing pin",
            date: JournalHarness.date(year: 2026, month: 8, day: 2),
            latitude: 999,
            longitude: 0,
            dog: harness.dog,
            in: harness.context
        )
        let invalidCurrent = JournalHarness.outing(
            place: "Broken",
            date: JournalHarness.date(year: 2026, month: 8, day: 3),
            latitude: .nan,
            longitude: .nan,
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        XCTAssertFalse(CLLocationCoordinate2DIsValid(invalidNext.coordinate))
        XCTAssertNil(OutingDistance.metersToNextOuting(from: valid, among: [valid, invalidNext]))
        XCTAssertNil(OutingDistance.metersToNextOuting(from: invalidCurrent, among: [invalidCurrent, valid]))
    }

    func testIgnoresAnotherDogsOutingAsNextPin() throws {
        let harness = try JournalHarness.makeContext()
        let other = Dog(name: "Other")
        harness.context.insert(other)
        let first = JournalHarness.outing(
            place: "Home",
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        let otherPin = JournalHarness.offset(from: first.latitude, first.longitude, northMeters: 200)
        _ = JournalHarness.outing(
            place: "Elsewhere",
            date: JournalHarness.date(year: 2026, month: 8, day: 2),
            latitude: otherPin.latitude,
            longitude: otherPin.longitude,
            dog: other,
            in: harness.context
        )
        try harness.context.save()

        XCTAssertNil(OutingDistance.nextOuting(after: first, among: Array(harness.context.insertedModels(of: Outing.self))))
    }

    func testLabelUsesNextPinCopy() throws {
        let harness = try JournalHarness.makeContext()
        let first = JournalHarness.outing(
            place: "River",
            date: JournalHarness.date(year: 2026, month: 8, day: 1),
            dog: harness.dog,
            in: harness.context
        )
        let nextPin = JournalHarness.offset(from: first.latitude, first.longitude, northMeters: 50)
        let next = JournalHarness.outing(
            place: "Bend",
            date: JournalHarness.date(year: 2026, month: 8, day: 2),
            latitude: nextPin.latitude,
            longitude: nextPin.longitude,
            dog: harness.dog,
            in: harness.context
        )
        try harness.context.save()

        let compact = OutingDistance.label(from: first, among: [first, next], usesMetric: true, compact: true)
        let full = OutingDistance.label(from: first, among: [first, next], usesMetric: true, compact: false)
        XCTAssertEqual(compact?.hasSuffix(" to next pin"), true)
        XCTAssertEqual(full?.hasSuffix(" to the next outing"), true)
        XCTAssertNil(OutingDistance.formattedAmount(9, usesMetric: true))
    }
}

private extension ModelContext {
    func insertedModels<T: PersistentModel>(of type: T.Type) -> [T] {
        ((try? fetch(FetchDescriptor<T>())) ?? [])
    }
}
