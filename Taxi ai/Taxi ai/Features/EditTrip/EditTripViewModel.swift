import CoreLocation
import MapKit
import SwiftUI

/// View model for the Edit Trip sheet, managing destination search and new route pricing.
@MainActor
@Observable
final class EditTripViewModel {
    // MARK: - Search State

    var searchText = ""
    var isSearchActive = false
    var selectedCategory: PlaceCategory = .bars
    var nearbyPlaces: [NearbyPlace] = []
    var isSearching = false

    /// When set, the user is exploring POIs around this destination before confirming.
    var selectedDestination: NearbyPlace?

    /// The newly selected destination, pending confirmation.
    var newDestination: NearbyPlace?

    // MARK: - Route & Pricing State

    var newRoute: MKRoute?
    var newTripInfo: TripInfo?
    var isCalculatingRoute = false

    /// Whether the price confirmation overlay is shown.
    var showPriceConfirmation = false

    /// Set to true when a selected destination exceeds the maximum service distance.
    var showTooFarAlert = false

    // MARK: - Dependencies

    private let locationService: LocationService
    private let currencyService: CurrencyService
    private let searchCompleterService = SearchCompleterService()
    private let routeService = RouteService()

    /// The original trip price before editing, used to calculate the difference.
    private let originalPrice: Double?

    /// The coordinate to route from (current taxi position or pickup location).
    private let routeOrigin: CLLocationCoordinate2D

    /// Distance already driven in meters before this destination change, for accurate pricing.
    private let distanceAlreadyDriven: CLLocationDistance

    /// The minimum price for the trip (original price before any mid-ride changes).
    /// When set, the new price will never drop below this value.
    private let minimumPrice: Double?

    // MARK: - Init

    /// Creates the view model with shared services from the active trip.
    /// - Parameters:
    ///   - locationService: Shared location service for user position and search biasing.
    ///   - currencyService: Shared currency service for consistent price display.
    ///   - originalPrice: The current trip's estimated price, for computing the difference.
    ///   - routeOrigin: The coordinate to calculate the new route from.
    ///   - distanceAlreadyDriven: Meters already driven before this change (0 for pre-ride edits).
    ///   - minimumPrice: Price floor to enforce during active rides (nil for pre-ride edits).
    init(
        locationService: LocationService,
        currencyService: CurrencyService,
        originalPrice: Double?,
        routeOrigin: CLLocationCoordinate2D,
        distanceAlreadyDriven: CLLocationDistance = 0,
        minimumPrice: Double? = nil
    ) {
        self.locationService = locationService
        self.currencyService = currencyService
        self.originalPrice = originalPrice
        self.routeOrigin = routeOrigin
        self.distanceAlreadyDriven = distanceAlreadyDriven
        self.minimumPrice = minimumPrice
    }

    // MARK: - Computed Properties

    /// Autocomplete suggestions from the search completer.
    var currentCompletions: [SearchCompletion] {
        searchCompleterService.completions
    }

    /// Estimated price for the new route in the user's currency.
    /// Includes distance already driven and enforces the minimum price floor when set.
    var newEstimatedPrice: Double? {
        guard let newTripInfo else { return nil }
        let totalMeters = distanceAlreadyDriven + newTripInfo.distance
        let miles = Measurement(
            value: totalMeters,
            unit: UnitLength.meters
        ).converted(to: .miles).value
        let usd = TripViewModel.baseFare + TripViewModel.perMileRate * miles
        let converted = currencyService.convertFromUSD(usd)
        if let minimumPrice {
            return max(converted, minimumPrice)
        }
        return converted
    }

    /// The price difference between the new and original routes.
    var priceDifference: Double? {
        guard let newPrice = newEstimatedPrice,
              let originalPrice else { return nil }
        return newPrice - originalPrice
    }

    /// The currency code for display.
    var displayCurrencyCode: String {
        currencyService.displayCurrencyCode
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

        // Recalculate distance from route origin.
        var destination = resolvedPlace
        let originLocation = CLLocation(
            latitude: routeOrigin.latitude,
            longitude: routeOrigin.longitude
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
            distance: originLocation.distance(from: destLocation)
        )

        // Check service area.
        let distanceMiles = Measurement(value: destination.distance, unit: UnitLength.meters)
            .converted(to: .miles).value
        if distanceMiles > HomeViewModel.maxDistanceMiles {
            showTooFarAlert = true
            isSearching = false
            searchText = ""
            return
        }

        // Enter exploration mode — show destination banner and POIs around it.
        selectedDestination = destination
        searchText = destination.name

        await searchNearbyPlacesAround(destination.coordinate, for: selectedCategory)
    }

    /// Clears the search and resets to category browsing around the route origin.
    func clearSearch() {
        searchText = ""
        isSearchActive = false
        selectedDestination = nil
        newDestination = nil
        newRoute = nil
        newTripInfo = nil
        showPriceConfirmation = false
        searchCompleterService.completions = []
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

    /// Loads places for the initial category.
    func loadInitialPlaces() async {
        await searchNearbyPlaces(for: selectedCategory)
    }

    // MARK: - Destination Selection

    /// Called when a place is selected from the list or search results.
    func selectNewDestination(_ place: NearbyPlace) async {
        newDestination = place
        searchText = place.name

        // Calculate the route to the new destination.
        isCalculatingRoute = true
        do {
            let calculatedRoute = try await routeService.calculateRoute(
                from: routeOrigin,
                to: place.coordinate
            )
            newRoute = calculatedRoute
            newTripInfo = TripInfo(
                distance: calculatedRoute.distance,
                expectedTravelTime: calculatedRoute.expectedTravelTime,
                routeName: calculatedRoute.name
            )
            showPriceConfirmation = true
        } catch {
            newRoute = nil
            newTripInfo = nil
        }
        isCalculatingRoute = false
    }

    // MARK: - Private

    /// Performs a local search for POIs near the route origin.
    private func searchNearbyPlaces(for category: PlaceCategory) async {
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = MKCoordinateRegion(
            center: routeOrigin,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let originLocation = CLLocation(
                latitude: routeOrigin.latitude,
                longitude: routeOrigin.longitude
            )

            nearbyPlaces = response.mapItems.prefix(10).map { item in
                let itemLocation = item.location
                let distance = originLocation.distance(from: itemLocation)

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

    /// Searches for POIs around a specific coordinate (used when exploring a destination).
    private func searchNearbyPlacesAround(
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

    // TODO: Migrate to MKAddressRepresentations when API stabilizes
    /// Formats a map item into a short address string.
    private func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        return [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
