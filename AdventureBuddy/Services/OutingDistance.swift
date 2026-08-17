import CoreLocation
import Foundation
import SwiftData

/// Straight-line distance between outings, using Settings miles/kilometers.
///
/// Rule: for an outing, this is the great-circle distance from that pin to the
/// **next outing in chronological order** that belongs to the same dog.
/// It is not walking distance, a GPS trail, or a route.
///
/// The latest outing (and any outing without a later sibling or a valid pin)
/// has no distance. Distances under 10 meters are omitted so the UI never
/// shows `0.0`.
///
/// Visible copy is “to next pin” / “to the next outing” so it is not read as a walk.
enum OutingDistance {
    static let minimumDisplayableMeters: CLLocationDistance = 10

    static func metersToNextOuting(from outing: Outing, among outings: [Outing]) -> CLLocationDistance? {
        guard CLLocationCoordinate2DIsValid(outing.coordinate) else { return nil }
        guard let next = nextOuting(after: outing, among: outings) else { return nil }
        guard CLLocationCoordinate2DIsValid(next.coordinate) else { return nil }

        let meters = CLLocation(latitude: outing.latitude, longitude: outing.longitude)
            .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
        guard meters.isFinite, meters >= minimumDisplayableMeters else { return nil }
        return meters
    }

    static func nextOuting(after outing: Outing, among outings: [Outing]) -> Outing? {
        let dogID = outing.dog?.persistentModelID
        let ordered = outings
            .filter { $0.dog?.persistentModelID == dogID }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.locationName.localizedStandardCompare(rhs.locationName) == .orderedAscending
            }

        guard let index = ordered.firstIndex(where: { $0.persistentModelID == outing.persistentModelID }),
              index + 1 < ordered.count else { return nil }
        return ordered[index + 1]
    }

    static func label(
        from outing: Outing,
        among outings: [Outing],
        usesMetric: Bool,
        compact: Bool
    ) -> String? {
        guard let meters = metersToNextOuting(from: outing, among: outings) else { return nil }
        guard let amount = formattedAmount(meters, usesMetric: usesMetric) else { return nil }
        if compact {
            return "\(amount) to next pin"
        }
        return "\(amount) to the next outing"
    }

    static func formattedAmount(_ meters: CLLocationDistance, usesMetric: Bool) -> String? {
        guard meters.isFinite, meters >= minimumDisplayableMeters else { return nil }

        if usesMetric {
            if meters < 1000 {
                return "\(Int(meters.rounded())) m"
            }
            let kilometers = meters / 1000
            return String(format: kilometers >= 10 ? "%.0f km" : "%.1f km", kilometers)
        }

        let miles = meters / 1609.344
        if miles < 0.1 {
            let feet = meters * 3.28084
            guard feet >= 30 else { return nil }
            return "\(Int(feet.rounded())) ft"
        }
        return String(format: miles >= 10 ? "%.0f mi" : "%.1f mi", miles)
    }
}
