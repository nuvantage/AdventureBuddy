import CoreLocation
import Foundation

protocol PlaceNameLooking: AnyObject {
    func placeName(for coordinate: CLLocationCoordinate2D) async -> String?
}

/// Reverse-geocodes a pin into a friendly place name.
///
/// Uses `CLGeocoder` so this works on iOS 17. `MKReverseGeocodingRequest` is
/// newer than the app’s deployment target, so it is not used here.
final class PlaceNameLookup: PlaceNameLooking {
    private let geocoder = CLGeocoder()

    func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return PlaceNameFormatter.friendlyName(from: placemark)
        } catch {
            return nil
        }
    }
}

enum PlaceNameFormatter {
    private static let namedPlaceHints = [
        "park", "trail", "hike", "peak", "mountain", "summit", "ridge",
        "beach", "lake", "river", "creek", "falls", "canyon", "meadow",
        "forest", "woods", "grove", "preserve", "garden", "overlook",
        "vista", "reservoir", "harbor", "marina", "wetland", "recreation"
    ]

    static func friendlyName(from placemark: CLPlacemark) -> String? {
        if let interests = placemark.areasOfInterest {
            if let interest = interests.compactMap({ cleaned($0) }).first {
                return interest
            }
        }

        if let water = [placemark.inlandWater, placemark.ocean].compactMap({ cleaned($0) }).first {
            return water
        }

        if let name = cleaned(placemark.name) {
            if looksLikeNamedPlace(name) || !isStreetAddress(name, placemark) {
                return name
            }
        }

        if let locality = cleaned(placemark.locality) {
            if let subLocality = cleaned(placemark.subLocality),
               subLocality.localizedCaseInsensitiveCompare(locality) != .orderedSame {
                return "\(subLocality), \(locality)"
            }
            return locality
        }

        if let subLocality = cleaned(placemark.subLocality) {
            return subLocality
        }

        return cleaned(placemark.administrativeArea)
    }

    private static func looksLikeNamedPlace(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return namedPlaceHints.contains { lowered.contains($0) }
    }

    private static func isStreetAddress(_ name: String, _ placemark: CLPlacemark) -> Bool {
        if looksLikeCoordinate(name) { return true }

        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { cleaned($0) }
            .joined(separator: " ")
        if !street.isEmpty, name.localizedCaseInsensitiveCompare(street) == .orderedSame {
            return true
        }

        if let thoroughfare = cleaned(placemark.thoroughfare),
           name.localizedCaseInsensitiveContains(thoroughfare),
           name.rangeOfCharacter(from: .decimalDigits) != nil {
            return true
        }

        return false
    }

    private static func looksLikeCoordinate(_ name: String) -> Bool {
        let parts = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return false }
        return Double(parts[0]) != nil && Double(parts[1]) != nil
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
