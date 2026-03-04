import Contacts
import MapKit
import SwiftUI

/// View model for the Home screen, managing location, category selection, search, and nearby place discovery.
@MainActor
@Observable
final class HomeViewModel {
    var selectedCategory: PlaceCategory = .bars
    var nearbyPlaces: [NearbyPlace] = []
    var isSearching = false
    var estimatedArrival = 5

    /// History of completed rides, newest first.
    var completedRides: [CompletedRide] = []

    /// Records a finished ride to the history.
    func addCompletedRide(_ ride: CompletedRide) {
        completedRides.insert(ride, at: 0)
    }

    // MARK: - Search State

    var searchText = ""
    var isSearchActive = false
    /// When set, POIs are loaded around this destination instead of the user's location.
    var selectedDestination: NearbyPlace?
    /// Set to true when a selected destination exceeds the maximum service distance.
    var showTooFarAlert = false

    /// Maximum service distance in miles.
    static let maxDistanceMiles: Double = 30

    let searchCompleterService = SearchCompleterService()
    let locationService = LocationService()

    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    /// Autocomplete suggestions from the search completer.
    var currentCompletions: [SearchCompletion] {
        searchCompleterService.completions
    }

    // MARK: - Lifecycle

    /// Requests location permission and begins updating.
    func onAppear() {
        locationService.requestPermission()
    }

    /// Waits for location to become available, then loads places for the default category.
    func loadInitialPlaces() async {
        // Poll until location becomes available
        while locationService.userLocation == nil {
            try? await Task.sleep(for: .milliseconds(500))
        }
        await searchNearbyPlaces(for: selectedCategory)
    }

    // MARK: - Search

    /// Called when the search text changes. Forwards the query to the completer.
    func updateSearchText(_ newText: String) {
        searchText = newText
        if newText.isEmpty {
            searchCompleterService.completions = []
        } else {
            if let userLocation = locationService.userLocation {
                searchCompleterService.updateRegion(
                    MKCoordinateRegion(
                        center: userLocation,
                        latitudinalMeters: 50_000,
                        longitudinalMeters: 50_000
                    )
                )
            }
            searchCompleterService.updateQuery(newText)
        }
    }

    /// Called when the user selects a completion from the autocomplete list.
    func selectSearchCompletion(_ completion: SearchCompletion) async {
        isSearchActive = false
        isSearching = true

        guard let resolvedPlace = await searchCompleterService.resolve(completion) else {
            isSearching = false
            return
        }

        // Recalculate distance from user to destination.
        var destination = resolvedPlace
        if let userLocation = locationService.userLocation {
            let userCLLocation = CLLocation(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            let destLocation = CLLocation(
                latitude: destination.coordinate.latitude,
                longitude: destination.coordinate.longitude
            )
            destination = NearbyPlace(
                id: destination.id,
                name: destination.name,
                address: destination.address,
                coordinate: destination.coordinate,
                distance: userCLLocation.distance(from: destLocation)
            )
        }

        // Check if the destination is within the service area.
        let distanceMiles = Measurement(value: destination.distance, unit: UnitLength.meters)
            .converted(to: .miles).value
        if distanceMiles > Self.maxDistanceMiles {
            showTooFarAlert = true
            isSearching = false
            searchText = ""
            return
        }

        selectedDestination = destination
        searchText = destination.name

        // Move camera to the destination area.
        cameraPosition = .region(
            MKCoordinateRegion(
                center: destination.coordinate,
                latitudinalMeters: 2000,
                longitudinalMeters: 2000
            )
        )

        // Search for POIs around the destination.
        await searchNearbyPlacesAround(destination.coordinate, for: selectedCategory)
    }

    /// Clears the search and returns to normal mode (POIs near user).
    func clearSearch() {
        searchText = ""
        isSearchActive = false
        selectedDestination = nil
        searchCompleterService.completions = []
        cameraPosition = .userLocation(fallback: .automatic)
        Task {
            await searchNearbyPlaces(for: selectedCategory)
        }
    }

    // MARK: - Categories

    /// Searches for nearby places matching the given category, respecting destination mode.
    func selectCategory(_ category: PlaceCategory) {
        selectedCategory = category
        Task {
            if let destination = selectedDestination {
                await searchNearbyPlacesAround(destination.coordinate, for: category)
            } else {
                await searchNearbyPlaces(for: category)
            }
        }
    }

    // MARK: - POI Search

    /// Performs a local search for POIs near the user's current location.
    func searchNearbyPlaces(for category: PlaceCategory) async {
        guard let userLocation = locationService.userLocation else { return }

        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = MKCoordinateRegion(
            center: userLocation,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let userCLLocation = CLLocation(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )

            nearbyPlaces = response.mapItems.prefix(10).map { item in
                let itemLocation = item.location
                let distance = userCLLocation.distance(from: itemLocation)

                return NearbyPlace(
                    id: item.identifier?.rawValue ?? item.name ?? UUID().uuidString,
                    name: item.name ?? "Unknown",
                    address: formatAddress(item),
                    coordinate: itemLocation.coordinate,
                    distance: distance
                )
            }
            .sorted { $0.distance < $1.distance }
        } catch {
            nearbyPlaces = []
        }

        isSearching = false
    }

    /// Searches for POIs around a specific coordinate (used when a destination is selected).
    func searchNearbyPlacesAround(
        _ center: CLLocationCoordinate2D,
        for category: PlaceCategory
    ) async {
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let centerLocation = CLLocation(
                latitude: center.latitude,
                longitude: center.longitude
            )

            nearbyPlaces = response.mapItems.prefix(10).map { item in
                let itemLocation = item.location
                let distance = centerLocation.distance(from: itemLocation)

                return NearbyPlace(
                    id: item.identifier?.rawValue ?? item.name ?? UUID().uuidString,
                    name: item.name ?? "Unknown",
                    address: formatAddress(item),
                    coordinate: itemLocation.coordinate,
                    distance: distance
                )
            }
            .sorted { $0.distance < $1.distance }
        } catch {
            nearbyPlaces = []
        }

        isSearching = false
    }

    // MARK: - Private

    /// Formats a map item into a short address string using placemark data.
    @available(iOS, deprecated: 26.0, message: "Migrate to MKAddressRepresentations when API stabilizes")
    private func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        return [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
