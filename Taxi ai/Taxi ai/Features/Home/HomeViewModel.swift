import Contacts
import MapKit
import SwiftUI

/// View model for the Home screen, managing location, category selection, and nearby place search.
@MainActor
@Observable
final class HomeViewModel {
    var selectedCategory: PlaceCategory = .bars
    var nearbyPlaces: [NearbyPlace] = []
    var isSearching = false
    var estimatedArrival = 12

    let locationService = LocationService()

    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

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

    /// Searches for nearby places matching the given category.
    func selectCategory(_ category: PlaceCategory) {
        selectedCategory = category
        Task {
            await searchNearbyPlaces(for: category)
        }
    }

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

    /// Formats a map item into a short address string using placemark data.
    @available(iOS, deprecated: 26.0, message: "Migrate to MKAddressRepresentations when API stabilizes")
    private func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        return [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
