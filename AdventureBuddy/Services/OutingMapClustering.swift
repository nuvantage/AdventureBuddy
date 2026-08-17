import CoreLocation
import Foundation
import MapKit
import SwiftData

/// Groups nearby outing pins by the current map span so a season of walks
/// does not stack. No third-party SDK, routes, or heatmaps.
enum OutingMapClustering {
    static let gridDivisions = 8.0
    static let stackedMeters: CLLocationDistance = 25
    static let minimumCellDegrees = 0.00018

    struct Cluster: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let outings: [Outing]

        var count: Int { outings.count }
    }

    /// Pins stay individual; nearby outings at the current zoom become a cluster.
    static func grouped(
        from outings: [Outing],
        span: MKCoordinateSpan,
        selectedID: PersistentIdentifier?
    ) -> (pins: [Outing], clusters: [Cluster]) {
        let selected = outings.first { $0.persistentModelID == selectedID }
        let remainder = outings.filter {
            $0.persistentModelID != selectedID && CLLocationCoordinate2DIsValid($0.coordinate)
        }

        var buckets: [GridKey: [Outing]] = [:]
        let cellLatitude = cellSize(span.latitudeDelta)
        let cellLongitude = cellSize(span.longitudeDelta)

        for outing in remainder {
            let key = GridKey(
                latitudeIndex: Int(floor((outing.latitude + 90) / cellLatitude)),
                longitudeIndex: Int(floor((outing.longitude + 180) / cellLongitude))
            )
            buckets[key, default: []].append(outing)
        }

        var pins: [Outing] = []
        var clusters: [Cluster] = []
        for (key, members) in buckets {
            if members.count == 1, let outing = members.first {
                pins.append(outing)
            } else {
                clusters.append(Cluster(
                    id: "cluster-\(key.latitudeIndex)-\(key.longitudeIndex)",
                    coordinate: centroid(of: members),
                    outings: members.sorted { $0.date > $1.date }
                ))
            }
        }

        if let selected, CLLocationCoordinate2DIsValid(selected.coordinate) {
            pins.append(selected)
        }
        return (pins, clusters)
    }

    static func areStacked(_ outings: [Outing]) -> Bool {
        guard let first = outings.first else { return true }
        let origin = CLLocation(latitude: first.latitude, longitude: first.longitude)
        return outings.allSatisfy { outing in
            guard CLLocationCoordinate2DIsValid(outing.coordinate) else { return false }
            return origin.distance(
                from: CLLocation(latitude: outing.latitude, longitude: outing.longitude)
            ) <= stackedMeters
        }
    }

    static func expansionRegion(for outings: [Outing]) -> MKCoordinateRegion {
        MapViewModel.region(
            containing: outings,
            extraPadding: 2.2,
            minimumSpan: 0.006
        )
    }

    private static func cellSize(_ spanDelta: CLLocationDegrees) -> CLLocationDegrees {
        max(spanDelta / gridDivisions, minimumCellDegrees)
    }

    private static func centroid(of outings: [Outing]) -> CLLocationCoordinate2D {
        let count = Double(outings.count)
        guard count > 0 else {
            return kCLLocationCoordinate2DInvalid
        }
        let latitude = outings.reduce(0) { $0 + $1.latitude } / count
        let longitude = outings.reduce(0) { $0 + $1.longitude } / count
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private struct GridKey: Hashable {
        let latitudeIndex: Int
        let longitudeIndex: Int
    }
}
