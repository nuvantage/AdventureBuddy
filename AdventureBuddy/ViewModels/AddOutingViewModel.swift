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
    var isLookingUpPlace = false
    var resolvedPlaceName: String?
    var placeLookupFailed = false

    private let locationService: LocationServicing
    private let placeLookup: PlaceNameLooking
    private let isEditingExisting: Bool
    private var shouldApplyIncomingLocation = true
    private var isProgrammaticCameraChange = false
    private var skipNextUserCameraUpdate = true
    private var lastKnownCoordinate: CLLocationCoordinate2D?
    private var userProvidedLocationName = false
    private var lastAutoFilledName: String?
    private var lastLookedUpCoordinate: CLLocationCoordinate2D?
    private var lookupTask: Task<Void, Never>?
    private var lookupGeneration = 0

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

    var placeCaption: String? {
        guard hasPlacedPin else { return nil }
        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLookingUpPlace, trimmedName.isEmpty {
            return "Looking up this place…"
        }
        if !trimmedName.isEmpty {
            return "Using: \(trimmedName)"
        }
        if placeLookupFailed {
            return "Couldn’t name this pin. Type a name, or tap to try again."
        }
        if isLookingUpPlace {
            return "Looking up this place…"
        }
        return "Tap to look up this place."
    }

    var navigationTitle: String {
        isEditingExisting ? "Edit outing" : "New outing"
    }

    func updateLocationNameFromUser(_ name: String) {
        locationName = name
        userProvidedLocationName = !nameIsEmpty(name)
        if nameIsEmpty(name) {
            lastAutoFilledName = nil
        }
    }

    init(
        outing: Outing? = nil,
        locationService: LocationServicing = LocationService(),
        placeLookup: PlaceNameLooking = PlaceNameLookup()
    ) {
        self.locationService = locationService
        self.placeLookup = placeLookup
        self.authorizationStatus = locationService.authorizationStatus
        self.isEditingExisting = outing != nil
        self.cameraPosition = .region(Self.defaultRegion)
        self.shouldApplyIncomingLocation = outing == nil

        if let outing {
            activity = Outing.Activity(rawValue: outing.activityType) ?? .other
            date = outing.date
            locationName = outing.locationName
            notes = outing.notes ?? ""
            photoData = outing.photoData
            latitude = outing.latitude
            longitude = outing.longitude
            skipNextUserCameraUpdate = true
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: outing.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
            userProvidedLocationName = !nameIsEmpty(outing.locationName)
        }

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
            locationService.startUpdatingLocation()
        }
        if hasPlacedPin {
            schedulePlaceLookup()
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

    func refreshPlaceName() {
        schedulePlaceLookup(force: true)
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
        guard let values = fieldValues() else { return nil }
        return Outing(
            date: date,
            latitude: values.latitude,
            longitude: values.longitude,
            locationName: values.locationName,
            activityType: activity.rawValue,
            notes: values.notes,
            photoData: photoData,
            dog: dog
        )
    }

    @discardableResult
    func applyChanges(to outing: Outing) -> Bool {
        guard let values = fieldValues() else { return false }
        outing.date = date
        outing.latitude = values.latitude
        outing.longitude = values.longitude
        outing.locationName = values.locationName
        outing.activityType = activity.rawValue
        outing.notes = values.notes
        outing.photoData = photoData
        return true
    }

    private func fieldValues() -> (locationName: String, notes: String?, latitude: Double, longitude: Double)? {
        let name = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let latitude, let longitude else { return nil }
        return (name, trimmedNotes.isEmpty ? nil : trimmedNotes, latitude, longitude)
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
        schedulePlaceLookup()
    }

    private func schedulePlaceLookup(force: Bool = false) {
        guard let coordinate = pinCoordinate else { return }

        if !force,
           let lastLookedUpCoordinate,
           !placeLookupFailed,
           distance(from: lastLookedUpCoordinate, to: coordinate) < Self.lookupMinimumDistance {
            return
        }

        lookupTask?.cancel()
        lookupGeneration += 1
        let generation = lookupGeneration
        isLookingUpPlace = true
        placeLookupFailed = false

        lookupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if !force {
                do {
                    try await Task.sleep(nanoseconds: Self.lookupDebounceNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled, generation == self.lookupGeneration else { return }

            let name = await self.placeLookup.placeName(for: coordinate)
            guard !Task.isCancelled, generation == self.lookupGeneration else { return }
            self.applyLookupResult(name, for: coordinate)
        }
    }

    private func applyLookupResult(_ name: String?, for coordinate: CLLocationCoordinate2D) {
        isLookingUpPlace = false
        lastLookedUpCoordinate = coordinate
        resolvedPlaceName = name
        placeLookupFailed = name == nil

        guard let name else {
            if !userProvidedLocationName, locationName == lastAutoFilledName {
                locationName = ""
                lastAutoFilledName = nil
            }
            return
        }

        if shouldApplySuggestedName {
            locationName = name
            lastAutoFilledName = name
        }
    }

    private var shouldApplySuggestedName: Bool {
        !userProvidedLocationName || nameIsEmpty(locationName)
    }

    private func nameIsEmpty(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func distance(from lhs: CLLocationCoordinate2D, to rhs: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }

    private static let lookupDebounceNanoseconds: UInt64 = 400_000_000
    private static let lookupMinimumDistance: CLLocationDistance = 25

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
}
