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
