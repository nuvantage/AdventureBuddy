import CoreLocation
import Foundation
import SwiftData

@Model
final class Outing {
    var date: Date
    var latitude: Double
    var longitude: Double
    var locationName: String
    var activityType: String
    var notes: String?
    @Attribute(.externalStorage) var photoData: Data?
    var dog: Dog?

    init(
        date: Date,
        latitude: Double,
        longitude: Double,
        locationName: String,
        activityType: String,
        notes: String? = nil,
        photoData: Data? = nil,
        dog: Dog? = nil
    ) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.activityType = activityType
        self.notes = notes
        self.photoData = photoData
        self.dog = dog
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var activityTitle: String {
        Activity(rawValue: activityType)?.title ?? activityType.localizedCapitalized
    }

    var activitySymbolName: String {
        Activity(rawValue: activityType)?.symbolName ?? "pawprint.fill"
    }

    /// Trimmed, lowercase location used for “distinct places” (same rule as ten-places).
    var distinctLocationKey: String? {
        let key = locationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return key.isEmpty ? nil : key
    }

    /// True when the stored time is not midnight, so we can show it without
    /// implying a 12:00 AM walk for date-only outings from earlier builds.
    var hasDisplayableTimeOfDay: Bool {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
    }

    var listDateText: String {
        if hasDisplayableTimeOfDay {
            date.formatted(date: .abbreviated, time: .shortened)
        } else {
            date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    var detailDateText: String {
        if hasDisplayableTimeOfDay {
            date.formatted(date: .long, time: .shortened)
        } else {
            date.formatted(date: .long, time: .omitted)
        }
    }

    /// Short line for the system share sheet, e.g. “Eagle Peak · Hike · Aug 10, 2026”.
    var shareText: String {
        let place = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let when = date.formatted(date: .abbreviated, time: .omitted)
        return "\(place) · \(activityTitle) · \(when)"
    }
}

extension Outing {
    enum Activity: String, CaseIterable, Identifiable, Hashable {
        case walk
        case hike
        case park
        case beach
        case trip
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .walk: "Walk"
            case .hike: "Hike"
            case .park: "Park"
            case .beach: "Beach"
            case .trip: "Trip"
            case .other: "Other"
            }
        }

        var symbolName: String {
            switch self {
            case .walk: "figure.walk"
            case .hike: "figure.hiking"
            case .park: "leaf.fill"
            case .beach: "water.waves"
            case .trip: "suitcase.fill"
            case .other: "pawprint.fill"
            }
        }
    }
}
