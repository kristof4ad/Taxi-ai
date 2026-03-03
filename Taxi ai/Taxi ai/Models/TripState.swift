import MapKit

/// The lifecycle states of a taxi simulation trip.
nonisolated enum SimulationState: Equatable, Sendable {
    case idle
    case selectingDestination
    case calculatingRoute
    case routeReady
    case approachingPickup(progress: Double)
    case arrivedAtPickup
    case simulating(progress: Double)
    case completed
    case error(String)
}

/// Summary information about the calculated route.
nonisolated struct TripInfo: Sendable {
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let routeName: String
}
