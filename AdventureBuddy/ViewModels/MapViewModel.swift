import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class MapViewModel {
    var cameraPosition: MapCameraPosition
    var selectedOuting: Outing?
    var authorizationStatus: CLAuthorizationStatus
    var showsLocationPrompt: Bool

    private let locationService: LocationServicing
    private var hasCenteredOnUser = false
    private var lastKnownCoordinate: CLLocationCoordinate2D?

    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isLocationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    init(locationService: LocationServicing = LocationService()) {
        self.locationService = locationService
        self.authorizationStatus = locationService.authorizationStatus
        self.showsLocationPrompt = locationService.authorizationStatus == .notDetermined
        self.cameraPosition = .region(Self.fallbackRegion)

        locationService.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.handleAuthorization(status)
            }
        }
        locationService.onLocation = { [weak self] location in
            Task { @MainActor in
                self?.handleLocation(location)
            }
        }

        if isLocationAuthorized {
            locationService.startUpdatingLocation()
        }
    }

    func requestLocationAccess() {
        showsLocationPrompt = false
        locationService.requestWhenInUseAuthorization()
    }

    func deferLocationAccess() {
        showsLocationPrompt = false
    }

    func select(_ outing: Outing) {
        selectedOuting = outing
        cameraPosition = .region(
            MKCoordinateRegion(
                center: outing.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
    }

    func clearSelection() {
        selectedOuting = nil
    }

    func centerOnUserIfAvailable() {
        if let lastKnownCoordinate {
            cameraPosition = .userRegion(lastKnownCoordinate)
            return
        }

        hasCenteredOnUser = false
        locationService.startUpdatingLocation()
    }

    func showAllOutings(_ outings: [Outing]) {
        selectedOuting = nil
        cameraPosition = .region(Self.region(containing: outings))
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        showsLocationPrompt = false

        if isLocationAuthorized {
            locationService.startUpdatingLocation()
        } else {
            locationService.stopUpdatingLocation()
        }
    }

    private func handleLocation(_ location: CLLocation) {
        lastKnownCoordinate = location.coordinate
        guard !hasCenteredOnUser else { return }
        hasCenteredOnUser = true
        cameraPosition = .userRegion(location.coordinate)
    }

    static func region(containing outings: [Outing]) -> MKCoordinateRegion {
        let coordinates = outings.map(\.coordinate)
        guard let first = coordinates.first else {
            return fallbackRegion
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.8, 0.04),
                longitudeDelta: max((maxLon - minLon) * 1.8, 0.04)
            )
        )
    }

    static let fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
}

private extension MapCameraPosition {
    static func userRegion(_ coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            )
        )
    }
}
