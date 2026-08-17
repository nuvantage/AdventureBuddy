import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// On-device journal copy for the share sheet. This is not a live backup, import, or iCloud.
enum JournalExport {
    static let format = "AdventureBuddy.journal"
    static let formatVersion = 1
    /// Raw JPEG bytes (companion + outing photos) that still fit in one shareable package.
    static let photoByteBudget = 20 * 1024 * 1024
    static let copyNotice = "This file is a copy of the Adventure Buddy journal, not a live backup. Removing the companion or losing the phone still wipes the journal on the device. Photos stay on the phone when they would make this file too large."

    struct Document: Codable, Equatable {
        var format: String
        var formatVersion: Int
        var exportedAt: Date
        var copyNotice: String
        var photosIncluded: Bool
        var photosOmittedBecauseTooLarge: Bool
        var photosNote: String
        var dog: ExportedDog
        var outings: [ExportedOuting]
        var milestones: [ExportedMilestone]
    }

    struct ExportedDog: Codable, Equatable {
        var name: String
        var breed: String?
        var birthdate: Date?
        var photoFile: String?
        var hadPhotoOnDevice: Bool
    }

    struct ExportedOuting: Codable, Equatable {
        var date: Date
        var latitude: Double
        var longitude: Double
        var locationName: String
        var activity: String
        var notes: String?
        var photoFile: String?
        var hadPhotoOnDevice: Bool
    }

    struct ExportedMilestone: Codable, Equatable {
        var catalogID: String
        var name: String
        var dateEarned: Date?
    }

    struct Package: Equatable {
        var document: Document
        var fileData: Data
        var filename: String
        var contentType: UTType

        var photosIncluded: Bool { document.photosIncluded }
        var photosOmittedBecauseTooLarge: Bool { document.photosOmittedBecauseTooLarge }
    }

    struct File: Equatable {
        var url: URL
        var filename: String
        var contentType: UTType
        var photosIncluded: Bool
        var photosOmittedBecauseTooLarge: Bool
        var photosNote: String
    }

    static func makePackage(
        dog: Dog,
        outings: [Outing],
        milestones: [Milestone],
        now: Date = Date()
    ) throws -> Package {
        let sortedOutings = outings.sorted { $0.date < $1.date }
        let photoPlan = planPhotos(dog: dog, outings: sortedOutings)
        let document = Document(
            format: format,
            formatVersion: formatVersion,
            exportedAt: now,
            copyNotice: copyNotice,
            photosIncluded: photoPlan.includePhotos,
            photosOmittedBecauseTooLarge: photoPlan.omittedBecauseTooLarge,
            photosNote: photoPlan.note,
            dog: ExportedDog(
                name: dog.name,
                breed: dog.breed,
                birthdate: dog.birthdate,
                photoFile: photoPlan.companionPhotoName,
                hadPhotoOnDevice: photoBytes(dog.photoData) > 0
            ),
            outings: Swift.zip(sortedOutings, photoPlan.outingPhotoNames).map { outing, photoFile in
                ExportedOuting(
                    date: outing.date,
                    latitude: outing.latitude,
                    longitude: outing.longitude,
                    locationName: outing.locationName,
                    activity: outing.activityType,
                    notes: outing.notes,
                    photoFile: photoFile,
                    hadPhotoOnDevice: photoBytes(outing.photoData) > 0
                )
            },
            milestones: milestones.map { milestone in
                ExportedMilestone(
                    catalogID: milestone.catalogID,
                    name: milestone.name,
                    dateEarned: milestone.dateEarned
                )
            }
        )

        let json = try jsonData(from: document)
        let filenameStem = filenameStem(dogName: dog.name, now: now)

        if photoPlan.includePhotos {
            var entries = [StoredZip.Entry(path: "journal.json", data: json)]
            for (name, bytes) in photoPlan.files {
                entries.append(StoredZip.Entry(path: name, data: bytes))
            }
            return Package(
                document: document,
                fileData: StoredZip.data(from: entries),
                filename: "\(filenameStem).zip",
                contentType: .zip
            )
        }

        return Package(
            document: document,
            fileData: json,
            filename: "\(filenameStem).json",
            contentType: .json
        )
    }

    static func jsonData(from document: Document) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(document)
        } catch {
            throw JournalExportError.encodingFailed
        }
    }

    static func write(_ package: Package, into directory: URL) throws -> File {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(package.filename)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try package.fileData.write(to: url, options: .atomic)
            return File(
                url: url,
                filename: package.filename,
                contentType: package.contentType,
                photosIncluded: package.photosIncluded,
                photosOmittedBecauseTooLarge: package.photosOmittedBecauseTooLarge,
                photosNote: package.document.photosNote
            )
        } catch let error as JournalExportError {
            throw error
        } catch {
            throw JournalExportError.writeFailed
        }
    }

    static func filenameStem(dogName: String, now: Date) -> String {
        let day = ISO8601DateFormatter.string(from: now, dateOnly: true)
        let name = sanitizedFilename(dogName)
        if name.isEmpty {
            return "AdventureBuddy-journal-\(day)"
        }
        return "AdventureBuddy-\(name)-journal-\(day)"
    }

    static func sanitizedFilename(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let mapped = String(trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let collapsed = mapped
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return String(collapsed.prefix(40))
    }
}

enum JournalExportError: LocalizedError, Equatable {
    case encodingFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Couldn’t build the journal file. Nothing was shared."
        case .writeFailed:
            "Couldn’t save the journal file to share. Nothing was shared."
        }
    }
}

extension JournalExport.File: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { file in
            SentTransferredFile(file.url)
        }
        .exportingCondition { $0.contentType.conforms(to: .zip) }
        .suggestedFileName { $0.filename }

        FileRepresentation(exportedContentType: .json) { file in
            SentTransferredFile(file.url)
        }
        .exportingCondition { $0.contentType.conforms(to: .json) }
        .suggestedFileName { $0.filename }
    }
}

private struct PhotoPlan {
    var includePhotos: Bool
    var omittedBecauseTooLarge: Bool
    var note: String
    var companionPhotoName: String?
    var outingPhotoNames: [String?]
    var files: [(name: String, data: Data)]
}

private func planPhotos(dog: Dog, outings: [Outing]) -> PhotoPlan {
    let companion = photoDataIfPresent(dog.photoData)
    let outingPhotos = outings.map { photoDataIfPresent($0.photoData) }
    let totalBytes = photoBytes(companion) + outingPhotos.reduce(0) { $0 + photoBytes($1) }

    if totalBytes == 0 {
        return PhotoPlan(
            includePhotos: false,
            omittedBecauseTooLarge: false,
            note: "No photos were stored with this journal.",
            companionPhotoName: nil,
            outingPhotoNames: Array(repeating: nil, count: outings.count),
            files: []
        )
    }

    if totalBytes > JournalExport.photoByteBudget {
        return PhotoPlan(
            includePhotos: false,
            omittedBecauseTooLarge: true,
            note: "Photos stay on this phone because they would make the export too large. Outing text and milestone dates are in this JSON.",
            companionPhotoName: nil,
            outingPhotoNames: Array(repeating: nil, count: outings.count),
            files: []
        )
    }

    var files: [(String, Data)] = []
    var companionName: String?
    if let companion {
        companionName = "photos/companion.jpg"
        files.append((companionName!, companion))
    }

    var outingNames: [String?] = []
    var index = 1
    for photo in outingPhotos {
        if let photo {
            let name = String(format: "photos/outing-%03d.jpg", index)
            index += 1
            outingNames.append(name)
            files.append((name, photo))
        } else {
            outingNames.append(nil)
        }
    }

    return PhotoPlan(
        includePhotos: true,
        omittedBecauseTooLarge: false,
        note: "JPEG photos are in this zip next to journal.json.",
        companionPhotoName: companionName,
        outingPhotoNames: outingNames,
        files: files
    )
}

private func photoDataIfPresent(_ data: Data?) -> Data? {
    guard let data, !data.isEmpty else { return nil }
    return data
}

private func photoBytes(_ data: Data?) -> Int {
    photoDataIfPresent(data)?.count ?? 0
}

private extension ISO8601DateFormatter {
    static func string(from date: Date, dateOnly: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = dateOnly ? [.withFullDate] : [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

/// Uncompressed zip so a journal copy can carry JSON plus JPEGs as one shareable file.
enum StoredZip {
    struct Entry {
        var path: String
        var data: Data
    }

    static func data(from entries: [Entry]) -> Data {
        var locals = Data()
        var central = Data()
        var offset: UInt32 = 0
        let (dosTime, dosDate) = dosDateTime(Date())

        for entry in entries {
            let name = Data(entry.path.utf8)
            let crc = CRC32.hash(entry.data)
            let size = UInt32(entry.data.count)

            var local = Data()
            local.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            local.appendLittleEndian(UInt16(20))
            local.appendLittleEndian(UInt16(0))
            local.appendLittleEndian(UInt16(0))
            local.appendLittleEndian(dosTime)
            local.appendLittleEndian(dosDate)
            local.appendLittleEndian(crc)
            local.appendLittleEndian(size)
            local.appendLittleEndian(size)
            local.appendLittleEndian(UInt16(name.count))
            local.appendLittleEndian(UInt16(0))
            local.append(name)

            let localOffset = offset
            locals.append(local)
            locals.append(entry.data)
            offset += UInt32(local.count + entry.data.count)

            var directory = Data()
            directory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            directory.appendLittleEndian(UInt16(20))
            directory.appendLittleEndian(UInt16(20))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(dosTime)
            directory.appendLittleEndian(dosDate)
            directory.appendLittleEndian(crc)
            directory.appendLittleEndian(size)
            directory.appendLittleEndian(size)
            directory.appendLittleEndian(UInt16(name.count))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt16(0))
            directory.appendLittleEndian(UInt32(0))
            directory.appendLittleEndian(localOffset)
            directory.append(name)
            central.append(directory)
        }

        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        eocd.appendLittleEndian(UInt16(0))
        eocd.appendLittleEndian(UInt16(0))
        eocd.appendLittleEndian(UInt16(entries.count))
        eocd.appendLittleEndian(UInt16(entries.count))
        eocd.appendLittleEndian(UInt32(central.count))
        eocd.appendLittleEndian(UInt32(locals.count))
        eocd.appendLittleEndian(UInt16(0))

        var zip = Data()
        zip.append(locals)
        zip.append(central)
        zip.append(eocd)
        return zip
    }
}

enum CRC32 {
    static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) == 1 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }
}

private func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
    let parts = Calendar.current.dateComponents(in: TimeZone.current, from: date)
    let year = UInt16(max((parts.year ?? 1980) - 1980, 0))
    let month = UInt16(parts.month ?? 1)
    let day = UInt16(parts.day ?? 1)
    let hour = UInt16(parts.hour ?? 0)
    let minute = UInt16(parts.minute ?? 0)
    let second = UInt16((parts.second ?? 0) / 2)
    let time = (hour << 11) | (minute << 5) | second
    let dosDate = (year << 9) | (month << 5) | day
    return (time, dosDate)
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
