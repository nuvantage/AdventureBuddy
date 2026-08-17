import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import AdventureBuddy

@MainActor
final class JournalExportTests: XCTestCase {
    func testJSONIncludesOutingFieldsAndMilestoneDates() throws {
        let harness = try JournalHarness.makeContext()
        let outingDate = JournalHarness.date(year: 2026, month: 4, day: 10, hour: 15)
        _ = JournalHarness.outing(
            place: "Eagle Peak",
            activity: .hike,
            date: outingDate,
            latitude: 38.5816,
            longitude: -121.4944,
            notes: "First ridge walk",
            dog: harness.dog,
            in: harness.context
        )
        let earned = JournalHarness.date(year: 2026, month: 4, day: 10)
        let firstWalk = try milestone("first-walk", in: harness.context)
        firstWalk.dateEarned = earned
        try harness.context.save()

        let package = try JournalExport.makePackage(
            dog: harness.dog,
            outings: CurrentDog.outings(try harness.context.fetch(FetchDescriptor<Outing>()), for: harness.dog),
            milestones: try harness.context.fetch(FetchDescriptor<Milestone>()),
            now: JournalHarness.date(year: 2026, month: 8, day: 17)
        )

        XCTAssertEqual(package.contentType, .json)
        XCTAssertTrue(package.filename.hasSuffix(".json"))
        XCTAssertFalse(package.photosIncluded)
        XCTAssertFalse(package.photosOmittedBecauseTooLarge)

        let document = try decode(package.fileData)
        XCTAssertEqual(document.format, JournalExport.format)
        XCTAssertTrue(document.copyNotice.contains("not a live backup"))
        XCTAssertEqual(document.dog.name, "Scout")
        XCTAssertEqual(document.outings.count, 1)
        XCTAssertEqual(document.outings[0].locationName, "Eagle Peak")
        XCTAssertEqual(document.outings[0].activity, Outing.Activity.hike.rawValue)
        XCTAssertEqual(document.outings[0].latitude, 38.5816)
        XCTAssertEqual(document.outings[0].longitude, -121.4944)
        XCTAssertEqual(document.outings[0].notes, "First ridge walk")
        XCTAssertEqual(document.outings[0].date, outingDate)
        XCTAssertEqual(document.milestones.first { $0.catalogID == "first-walk" }?.dateEarned, earned)
        XCTAssertNil(document.milestones.first { $0.catalogID == "first-hike" }?.dateEarned)
    }

    func testExportUsesOnlyOutingsPassedIn() throws {
        let harness = try JournalHarness.makeContext()
        let other = Dog(name: "Other")
        harness.context.insert(other)
        _ = JournalHarness.outing(
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

        let mine = CurrentDog.outings(try harness.context.fetch(FetchDescriptor<Outing>()), for: harness.dog)
        let document = try JournalExport.makePackage(
            dog: harness.dog,
            outings: mine,
            milestones: []
        ).document

        XCTAssertEqual(document.outings.map(\.locationName), ["River"])
    }

    func testPhotosGoIntoZipWhenTheyFit() throws {
        let harness = try JournalHarness.makeContext()
        harness.dog.photoData = Data("companion-jpeg".utf8)
        let outing = JournalHarness.outing(
            place: "Park",
            date: JournalHarness.date(year: 2026, month: 8, day: 3),
            dog: harness.dog,
            in: harness.context
        )
        outing.photoData = Data("outing-jpeg".utf8)
        try harness.context.save()

        let package = try JournalExport.makePackage(
            dog: harness.dog,
            outings: [outing],
            milestones: []
        )

        XCTAssertEqual(package.contentType, .zip)
        XCTAssertTrue(package.filename.hasSuffix(".zip"))
        XCTAssertTrue(package.photosIncluded)
        XCTAssertEqual(package.document.dog.photoFile, "photos/companion.jpg")
        XCTAssertEqual(package.document.outings[0].photoFile, "photos/outing-001.jpg")
        XCTAssertTrue(package.document.outings[0].hadPhotoOnDevice)

        let zip = package.fileData
        XCTAssertEqual(Array(zip.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
        XCTAssertTrue(containsASCII("journal.json", in: zip))
        XCTAssertTrue(containsASCII("photos/companion.jpg", in: zip))
        XCTAssertTrue(containsASCII("photos/outing-001.jpg", in: zip))
        XCTAssertTrue(containsASCII("companion-jpeg", in: zip))
        XCTAssertTrue(containsASCII("outing-jpeg", in: zip))
    }

    func testOversizedPhotosStayOnDeviceAndJSONStillExports() throws {
        let harness = try JournalHarness.makeContext()
        let outing = JournalHarness.outing(
            place: "Ridge",
            date: JournalHarness.date(year: 2026, month: 8, day: 4),
            notes: "Windy",
            dog: harness.dog,
            in: harness.context
        )
        outing.photoData = Data(repeating: 0xA1, count: JournalExport.photoByteBudget + 1)
        try harness.context.save()

        let package = try JournalExport.makePackage(
            dog: harness.dog,
            outings: [outing],
            milestones: []
        )

        XCTAssertEqual(package.contentType, .json)
        XCTAssertFalse(package.photosIncluded)
        XCTAssertTrue(package.photosOmittedBecauseTooLarge)
        XCTAssertTrue(package.document.photosNote.contains("stay on this phone"))
        XCTAssertNil(package.document.outings[0].photoFile)
        XCTAssertTrue(package.document.outings[0].hadPhotoOnDevice)
        XCTAssertEqual(package.document.outings[0].locationName, "Ridge")

        let document = try decode(package.fileData)
        XCTAssertEqual(document.outings[0].notes, "Windy")
    }

    func testWriteFailureIsReportedNotSwallowed() throws {
        let harness = try JournalHarness.makeContext()
        let package = try JournalExport.makePackage(dog: harness.dog, outings: [], milestones: [])
        let blocked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not-a-directory".utf8).write(to: blocked, options: .atomic)

        XCTAssertThrowsError(try JournalExport.write(package, into: blocked)) { error in
            XCTAssertEqual(error as? JournalExportError, .writeFailed)
        }
    }

    func testViewModelSurfacesWriteErrors() throws {
        let harness = try JournalHarness.makeContext()
        let blocked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not-a-directory".utf8).write(to: blocked, options: .atomic)
        let viewModel = JournalExportViewModel(directory: blocked)

        viewModel.prepare(dog: harness.dog, outings: [], milestones: [])

        XCTAssertNil(viewModel.preparedFile)
        XCTAssertTrue(viewModel.isShowingError)
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
        XCTAssertFalse(viewModel.errorMessage.contains("Optional"))
    }

    func testFilenameUsesCompanionName() {
        let stem = JournalExport.filenameStem(
            dogName: "Scout / Buddy!",
            now: JournalHarness.date(year: 2026, month: 8, day: 17)
        )
        XCTAssertEqual(stem, "AdventureBuddy-Scout-Buddy-journal-2026-08-17")
    }

    private func decode(_ data: Data) throws -> JournalExport.Document {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(JournalExport.Document.self, from: data)
    }

    private func milestone(_ catalogID: String, in context: ModelContext) throws -> Milestone {
        let found = try context.fetch(FetchDescriptor<Milestone>()).first { $0.catalogID == catalogID }
        return try XCTUnwrap(found)
    }

    private func containsASCII(_ text: String, in data: Data) -> Bool {
        data.range(of: Data(text.utf8)) != nil
    }
}
