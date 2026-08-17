import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class AddOutingViewModel {
    var activity: Outing.Activity = .walk
    var date = Date()
    var locationName = ""
    var notes = ""
    var photoData: Data?
    var cameraPosition: MapCameraPosition
    var latitude: Double?
    var longitude: Double?
    var authorizationStatus: CLAuthorizationStatus

    private let locationService: LocationServicing
    private var shouldApplyIncomingLocation = true
    private var isProgrammaticCameraChange = false
    private var skipNextUserCameraUpdate = true
    private var lastKnownCoordinate: CLLocationCoordinate2D?

    var hasPlacedPin: Bool {
        latitude != nil && longitude != nil
    }

    var canSave: Bool {
        let name = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && hasPlacedPin
    }

    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var pinCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(locationService: LocationServicing = LocationService()) {
        self.locationService = locationService
        self.authorizationStatus = locationService.authorizationStatus
        self.cameraPosition = .region(Self.defaultRegion)

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
    }

    func onAppear() {
        if isLocationAuthorized {
            shouldApplyIncomingLocation = true
            locationService.startUpdatingLocation()
        }
    }

    func useCurrentLocation() {
        shouldApplyIncomingLocation = true
        if authorizationStatus == .notDetermined {
            locationService.requestWhenInUseAuthorization()
            return
        }
        if let lastKnownCoordinate {
            shouldApplyIncomingLocation = false
            moveCamera(to: lastKnownCoordinate)
            return
        }
        if isLocationAuthorized {
            locationService.startUpdatingLocation()
        }
    }

    func updatePinFromCamera(_ coordinate: CLLocationCoordinate2D) {
        if isProgrammaticCameraChange {
            isProgrammaticCameraChange = false
            setPin(coordinate)
            return
        }

        if skipNextUserCameraUpdate {
            skipNextUserCameraUpdate = false
            return
        }

        shouldApplyIncomingLocation = false
        setPin(coordinate)
    }

    func makeOuting(dog: Dog) -> Outing? {
        let name = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let latitude, let longitude else { return nil }

        return Outing(
            date: date,
            latitude: latitude,
            longitude: longitude,
            locationName: name,
            activityType: activity.rawValue,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            photoData: photoData,
            dog: dog
        )
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if isLocationAuthorized, shouldApplyIncomingLocation {
            locationService.startUpdatingLocation()
        }
    }

    private func handleLocation(_ location: CLLocation) {
        lastKnownCoordinate = location.coordinate
        guard shouldApplyIncomingLocation else { return }
        shouldApplyIncomingLocation = false
        moveCamera(to: location.coordinate)
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        isProgrammaticCameraChange = true
        setPin(coordinate)
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    private func setPin(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
}
