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

    // MARK: - Search State

    var searchText = ""
    var isSearchActive = false
    /// When set, POIs are loaded around this destination instead of the user's location.
    var selectedDestination: NearbyPlace?
    /// Set to true when a selected destination exceeds the maximum service distance.
    var showTooFarAlert = false

    /// On-device AI helper, injected after the view model is created.
    var intelligenceService: IntelligenceService?

    private var interpretationTask: Task<Void, Never>?

    /// Incremented for every POI search so results that arrive after a newer
    /// search started can be discarded instead of overwriting fresher data.
    private var searchGeneration = 0

    /// Maximum service distance in miles.
    static let maxDistanceMiles: Double = 30

    /// Debounce delay before asking the on-device model for an interpretation.
    private static let interpretDebounce = Duration.milliseconds(300)

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
        // Poll until location becomes available. Exit promptly on cancellation —
        // `try?` would swallow the CancellationError and turn the loop into a CPU
        // spin as soon as the parent task is cancelled.
        while locationService.userLocation == nil {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }
        await searchNearbyPlaces(for: selectedCategory)
    }

    // MARK: - Search

    /// Called when the search text changes. Forwards the query to the completer
    /// and kicks off a debounced AI interpretation in the background.
    func updateSearchText(_ newText: String) {
        searchText = newText
        interpretationTask?.cancel()

        if newText.isEmpty {
            searchCompleterService.completions = []
            return
        }

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

        guard let intelligenceService, intelligenceService.isAvailable else { return }

        interpretationTask = Task { [weak self, newText] in
            try? await Task.sleep(for: Self.interpretDebounce)
            guard !Task.isCancelled else { return }
            let result = await intelligenceService.interpretSearch(newText)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard let result,
                  result.shouldSuggest,
                  !result.rewrittenQuery.isEmpty else { return }
            await self.applyRewrittenQuery(result.rewrittenQuery)
        }
    }

    /// Entry point for voice search submissions. Runs the on-device AI
    /// first and only touches `searchText` once the model has decided —
    /// so the user never sees the autocomplete overlay flash with results
    /// for the literal transcript before it's swapped for the rewrite.
    func submitVoiceQuery(_ transcript: String) async {
        interpretationTask?.cancel()

        if let intelligenceService, intelligenceService.isAvailable {
            let result = await intelligenceService.interpretSearch(transcript)
            if let result,
               result.shouldSuggest,
               !result.rewrittenQuery.isEmpty {
                await applyRewrittenQuery(result.rewrittenQuery)
                return
            }
        }

        // AI is off or declined to rewrite — fall back to the regular
        // autocomplete flow so the user can pick a literal match.
        isSearchActive = true
        searchText = transcript
    }

    /// Silently swaps the search bar for the AI's rewritten query, dismisses
    /// the autocomplete overlay, and runs a nearby-places search for the
    /// rewritten term — so conversational input like "I'm hungry" surfaces
    /// actual nearby restaurants instead of random literal matches.
    private func applyRewrittenQuery(_ rewrite: String) async {
        isSearchActive = false
        searchCompleterService.completions = []
        searchText = rewrite
        if let destination = selectedDestination {
            await searchNearbyPlacesAround(destination.coordinate, query: rewrite)
        } else {
            await searchNearbyPlaces(query: rewrite)
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
        // Keep the user's original query in the search bar so they retain
        // context. The destination banner is the source of truth for the
        // selected place — duplicating its name in the search field was
        // redundant and pushed content offscreen.

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
        interpretationTask?.cancel()
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

    /// Performs a local search for POIs near the user's current location,
    /// using the given category's search query.
    func searchNearbyPlaces(for category: PlaceCategory) async {
        await searchNearbyPlaces(query: category.searchQuery)
    }

    /// Performs a local search for POIs near the user's current location,
    /// using a free-form natural-language query (e.g. an AI-rewritten term).
    func searchNearbyPlaces(query: String) async {
        guard let userLocation = locationService.userLocation else { return }
        await runLocalSearch(query: query, center: userLocation)
    }

    /// Searches for POIs around a specific coordinate using a category's search query.
    func searchNearbyPlacesAround(
        _ center: CLLocationCoordinate2D,
        for category: PlaceCategory
    ) async {
        await searchNearbyPlacesAround(center, query: category.searchQuery)
    }

    /// Searches for POIs around a specific coordinate using a free-form query.
    func searchNearbyPlacesAround(
        _ center: CLLocationCoordinate2D,
        query: String
    ) async {
        await runLocalSearch(query: query, center: center)
    }

    private func runLocalSearch(query: String, center: CLLocationCoordinate2D) async {
        searchGeneration += 1
        let generation = searchGeneration
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )

        let places: [NearbyPlace]
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            let centerLocation = CLLocation(
                latitude: center.latitude,
                longitude: center.longitude
            )

            places = response.mapItems.prefix(10).map { item in
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
            places = []
        }

        // A newer search started while this one was in flight — its results win.
        guard generation == searchGeneration else { return }
        nearbyPlaces = places
        isSearching = false
    }

    // MARK: - Private

    /// Formats a map item into a short address string.
    private func formatAddress(_ item: MKMapItem) -> String {
        item.address?.shortAddress ?? ""
    }
}
