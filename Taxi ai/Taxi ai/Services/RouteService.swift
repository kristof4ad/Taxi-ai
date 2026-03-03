import CoreLocation
import MapKit

/// Calculates driving routes between two locations using Apple MapKit.
struct RouteService {
    /// Calculates a driving route from origin to destination.
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        request.source = MKMapItem(location: originLocation, address: nil)
        request.destination = MKMapItem(location: destinationLocation, address: nil)
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RouteError.noRouteFound
        }
        return route
    }
}

nonisolated enum RouteError: LocalizedError, Sendable {
    case noRouteFound

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            "No driving route could be found between these locations."
        }
    }
}
