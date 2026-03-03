import MapKit

/// A search autocomplete suggestion derived from MKLocalSearchCompleter.
nonisolated struct SearchCompletion: Identifiable, @unchecked Sendable {
    let id: String
    let title: String
    let subtitle: String

    /// The original completion object, used to perform a follow-up MKLocalSearch.
    let mapCompletion: MKLocalSearchCompletion

    init(from completion: MKLocalSearchCompletion) {
        self.id = "\(completion.title)-\(completion.subtitle)"
        self.title = completion.title
        self.subtitle = completion.subtitle
        self.mapCompletion = completion
    }
}
