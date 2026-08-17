import CoreLocation
import Foundation
import MapKit
import Observation
import SwiftData

@MainActor
@Observable
final class MapViewModel {
    var cameraPosition: MapCameraPosition
    var selectedOuting: Outing?
    var clusterPick: OutingMapClustering.Cluster?
    var authorizationStatus: CLAuthorizationStatus
    var showsLocationPrompt: Bool
    var visibleRegion: MKCoordinateRegion

    private let locationService: LocationServicing
    private var hasCenteredOnUser = false
    private var lastKnownCoordinate: CLLocationCoordinate2D?

    var visibleSpan: MKCoordinateSpan {
        visibleRegion.span
    }

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
        self.visibleRegion = Self.fallbackRegion

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

    func noteVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
    }

    func clusteredContent(for outings: [Outing]) -> (pins: [Outing], clusters: [OutingMapClustering.Cluster]) {
        OutingMapClustering.grouped(
            from: outings,
            span: visibleSpan,
            selectedID: selectedOuting?.persistentModelID
        )
    }

    func handleClusterTap(_ cluster: OutingMapClustering.Cluster) {
        if OutingMapClustering.areStacked(cluster.outings) {
            selectedOuting = nil
            clusterPick = cluster
            return
        }

        let target = OutingMapClustering.expansionRegion(for: cluster.outings)
        let alreadyExpanded =
            visibleRegion.span.latitudeDelta <= target.span.latitudeDelta * 1.35
            && visibleRegion.span.longitudeDelta <= target.span.longitudeDelta * 1.35
        if alreadyExpanded {
            selectedOuting = nil
            clusterPick = cluster
            return
        }

        clusterPick = nil
        selectedOuting = nil
        visibleRegion = target
        cameraPosition = .region(target)
    }

    func select(_ outing: Outing) {
        clusterPick = nil
        selectedOuting = outing
        let focused = MKCoordinateRegion(
            center: outing.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
        visibleRegion = focused
        cameraPosition = .region(focused)
    }

    func clearSelection() {
        selectedOuting = nil
    }

    func centerOnUserIfAvailable() {
        if let lastKnownCoordinate {
            cameraPosition = .userRegion(lastKnownCoordinate)
            visibleRegion = MKCoordinateRegion(
                center: lastKnownCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            )
            return
        }

        hasCenteredOnUser = false
        locationService.startUpdatingLocation()
    }

    func showAllOutings(_ outings: [Outing]) {
        selectedOuting = nil
        clusterPick = nil
        let region = Self.region(containing: outings)
        visibleRegion = region
        cameraPosition = .region(region)
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
        visibleRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    }

    static func region(containing outings: [Outing]) -> MKCoordinateRegion {
        region(containing: outings, extraPadding: 1.8, minimumSpan: 0.04)
    }

    static func region(
        containing outings: [Outing],
        extraPadding: Double,
        minimumSpan: CLLocationDegrees
    ) -> MKCoordinateRegion {
        let coordinates = outings.map(\.coordinate).filter { CLLocationCoordinate2DIsValid($0) }
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
                latitudeDelta: max((maxLat - minLat) * extraPadding, minimumSpan),
                longitudeDelta: max((maxLon - minLon) * extraPadding, minimumSpan)
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
