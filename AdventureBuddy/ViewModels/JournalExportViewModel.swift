import Foundation
import Observation

@MainActor
@Observable
final class JournalExportViewModel {
    var preparedFile: JournalExport.File?
    var isShowingError = false
    var errorMessage = ""
    var isPreparing = false

    private let directory: URL

    init(
        directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AdventureBuddyExport",
            isDirectory: true
        )
    ) {
        self.directory = directory
    }

    var photosOmittedBecauseTooLarge: Bool {
        preparedFile?.photosOmittedBecauseTooLarge ?? false
    }

    var photosIncluded: Bool {
        preparedFile?.photosIncluded ?? false
    }

    func prepare(dog: Dog, outings: [Outing], milestones: [Milestone], now: Date = Date()) {
        isPreparing = true
        preparedFile = nil
        do {
            let package = try JournalExport.makePackage(
                dog: dog,
                outings: outings,
                milestones: milestones,
                now: now
            )
            preparedFile = try JournalExport.write(package, into: directory)
        } catch {
            preparedFile = nil
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn’t create the journal file. Nothing was shared."
            isShowingError = true
        }
        isPreparing = false
    }
}
