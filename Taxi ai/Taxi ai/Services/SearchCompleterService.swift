import MapKit

/// Provides address and place autocomplete suggestions using MKLocalSearchCompleter.
@MainActor
@Observable
final class SearchCompleterService: NSObject, MKLocalSearchCompleterDelegate {
    var completions: [SearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Updates the query fragment, triggering new suggestions.
    func updateQuery(_ fragment: String) {
        completer.queryFragment = fragment
    }

    /// Biases results around a region (e.g. near the user's current location).
    func updateRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    /// Resolves a search completion into a place with coordinate and address.
    func resolve(_ completion: SearchCompletion) async -> NearbyPlace? {
        let request = MKLocalSearch.Request(completion: completion.mapCompletion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let location = item.location

            return NearbyPlace(
                id: item.identifier?.rawValue ?? item.name ?? UUID().uuidString,
                name: item.name ?? completion.title,
                address: formatAddress(item),
                coordinate: location.coordinate,
                distance: 0
            )
        } catch {
            return nil
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results.map { SearchCompletion(from: $0) }
        Task { @MainActor in
            self.completions = completions
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.completions = []
        }
    }

    // MARK: - Private

    @available(iOS, deprecated: 26.0, message: "Migrate to MKAddressRepresentations when API stabilizes")
    private func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        return [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
