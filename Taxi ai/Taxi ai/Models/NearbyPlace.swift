import CoreLocation
import MapKit

/// A nearby point of interest discovered through local search.
struct NearbyPlace: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance

    /// Formatted distance string (e.g. "0.1 mi").
    var formattedDistance: String {
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
