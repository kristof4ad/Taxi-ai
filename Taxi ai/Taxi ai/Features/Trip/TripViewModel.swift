import MapKit
import SwiftUI

/// Orchestrates the taxi simulation flow: destination selection, route calculation, and ride simulation.
@MainActor
@Observable
final class TripViewModel {
    // MARK: - Pricing

    /// Base fare in dollars.
    static let baseFare: Double = 2.00
    /// Per-mile rate in dollars.
    static let perMileRate: Double = 2.00
    /// Distance in meters before the destination where the ride ends, leaving room for walking directions.
    static let dropOffDistance: Double = 100

    // MARK: - State

    var simulationState: SimulationState = .idle
    var destination: CLLocationCoordinate2D?
    var destinationName: String?
    var destinationAddress: String?
    /// The rider's pickup address (street + city), captured via reverse geocoding when the ride starts.
    var pickupAddress: String?
    /// The date and time the ride started, used to calculate pickup and dropoff times.
    var rideStartDate: Date?
    var route: MKRoute?
    var tripInfo: TripInfo?
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    /// Whether the trunk is currently open, shared across exit and close-doors screens.
    var isTrunkOpen = false

    /// The coordinate where the car actually stops, approximately 300 m before the destination.
    /// Used later to show walking directions from here to the final destination.
    var dropOffLocation: CLLocationCoordinate2D?

    // MARK: - Destination Change Pricing

    /// Total meters driven across completed route segments (before the current one).
    private var accumulatedDrivenDistance: CLLocationDistance = 0

    /// The original route distance in meters, saved on the first mid-ride destination change.
    private var originalTripDistance: CLLocationDistance?

    /// The estimated price before any mid-ride destination changes, used as a price floor.
    private(set) var originalTripPrice: Double?

    /// Total distance driven so far: accumulated from previous segments plus current segment progress.
    var totalDistanceDriven: CLLocationDistance {
        accumulatedDrivenDistance + simulationEngine.distanceTraveled
    }

    /// The minimum ride price (the original trip price before any mid-ride changes).
    var minimumRidePrice: Double? {
        originalTripPrice ?? estimatedPrice
    }

    // MARK: - Pickup Approach State

    /// The car's current position as it approaches the pickup.
    var pickupCarPosition: CLLocationCoordinate2D?
    /// The road-snapped location where the car will stop for pickup (end of the approach route).
    var pickupStopLocation: CLLocationCoordinate2D?
    /// The calculated route from the car's start position to the pickup.
    var pickupRoute: MKRoute?
    /// Dedicated simulation engine for the pickup approach (separate from trip simulation).
    let pickupSimulationEngine = SimulationEngine()
    var pickupApproachTask: Task<Void, Never>?

    // MARK: - Services

    let locationService: LocationService
    let currencyService = CurrencyService()
    let simulationEngine = SimulationEngine()
    let routeService = RouteService()

    // MARK: - Init

    /// Creates a trip view model, optionally sharing a location service from the home screen.
    init(locationService: LocationService = LocationService()) {
        self.locationService = locationService
        Task {
            await currencyService.fetchExchangeRate()
        }
    }

    // MARK: - Computed Properties

    var canStartSimulation: Bool {
        simulationState == .routeReady
    }

    var showControlPanel: Bool {
        switch simulationState {
        case .routeReady, .simulating, .completed:
            true
        default:
            false
        }
    }

    var locationDenied: Bool {
        locationService.authorizationStatus == .denied
        || locationService.authorizationStatus == .restricted
    }

    var errorMessage: String? {
        if case .error(let message) = simulationState {
            return message
        }
        return nil
    }

    /// Estimated trip price in USD based on distance: $2 base + $2/mile.
    private var estimatedPriceUSD: Double? {
        guard let tripInfo else { return nil }
        let miles = Measurement(
            value: tripInfo.distance,
            unit: UnitLength.meters
        ).converted(to: .miles).value
        return Self.baseFare + Self.perMileRate * miles
    }

    /// Estimated trip price converted to the user's local currency.
    var estimatedPrice: Double? {
        guard let usd = estimatedPriceUSD else { return nil }
        return currencyService.convertFromUSD(usd)
    }

    /// The currency code to use when displaying prices.
    var displayCurrencyCode: String {
        currencyService.displayCurrencyCode
    }

    /// Estimated arrival time at the destination (pickup time + travel duration).
    var estimatedArrivalTime: Date? {
        guard let tripInfo else { return nil }
        return estimatedPickupTime.addingTimeInterval(tripInfo.expectedTravelTime)
    }

    /// Estimated pickup time (now + a few minutes for driver to arrive).
    var estimatedPickupTime: Date {
        Date.now.addingTimeInterval(60 * 7)
    }

    /// The remaining portion of the pickup approach route ahead of the car.
    var remainingPickupRouteCoordinates: [CLLocationCoordinate2D] {
        pickupSimulationEngine.remainingCoordinates
    }

    // MARK: - Actions

    func onAppear() {
        locationService.requestPermission()
        simulationState = .selectingDestination
    }

    func selectDestination(_ coordinate: CLLocationCoordinate2D) {
        guard simulationState == .selectingDestination else { return }
        destination = coordinate

        Task {
            await calculateRoute()
        }
    }

    /// Sets a destination from a nearby place and immediately calculates the route.
    func setDestination(from place: NearbyPlace) {
        destinationName = place.name
        destinationAddress = place.address
        simulationState = .selectingDestination
        selectDestination(place.coordinate)
    }

    /// Recenters the camera to show the full ride route.
    func recenterRideCamera() {
        guard let route else { return }
        let rect = route.polyline.boundingMapRect
        let padded = rect.insetBy(
            dx: -rect.size.width * 0.3,
            dy: -rect.size.height * 0.3
        )
        cameraPosition = .region(MKCoordinateRegion(padded))
    }

    func startSimulation() {
        guard simulationState == .routeReady, let route else { return }
        beginRideSimulation(with: route)
    }

    /// Starts the ride simulation from any state. Called when the ride screen appears.
    func startRide() {
        guard let route, !simulationEngine.isRunning else { return }
        rideStartDate = .now
        reverseGeocodePickupLocation()
        beginRideSimulation(with: route)
    }

    /// Configures and starts the simulation engine for a given route.
    /// The car stops approximately 300 m before the destination so walking directions can be shown.
    private func beginRideSimulation(with route: MKRoute) {
        let trimmedCoordinates = Self.trimmedRoute(
            route.coordinates,
            trailingMeters: Self.dropOffDistance
        )
        dropOffLocation = trimmedCoordinates.last
        simulationEngine.configure(with: trimmedCoordinates)
        simulationEngine.start()
        simulationState = .simulating(progress: 0)

        // Zoom camera to show the route.
        let mapRect = route.polyline.boundingMapRect
        let paddedRect = mapRect.insetBy(
            dx: -mapRect.size.width * 0.3,
            dy: -mapRect.size.height * 0.3
        )
        cameraPosition = .region(MKCoordinateRegion(paddedRect))

        // Monitor progress updates. Keep looping while running or paused so a
        // pause doesn't prematurely mark the ride as completed.
        Task {
            while simulationEngine.isRunning || simulationEngine.isPaused {
                if simulationEngine.isRunning {
                    simulationState = .simulating(progress: simulationEngine.progress)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            simulationState = .completed
        }
    }

    /// The best coordinate to route from when changing destinations mid-trip.
    /// Uses the taxi's current simulation position if riding, the pickup stop if pre-ride,
    /// or the user's location as a fallback.
    var currentRouteOrigin: CLLocationCoordinate2D? {
        if let currentPos = simulationEngine.currentPosition,
           simulationEngine.isRunning || simulationEngine.isPaused {
            return currentPos
        }
        if let pickupStop = pickupStopLocation {
            return pickupStop
        }
        return locationService.userLocation
    }

    /// Changes the trip destination to a new place. Recalculates the route from the
    /// current position and restarts the simulation if the ride is in progress.
    ///
    /// When the ride is active, the new price accounts for distance already driven
    /// and is floored at the original trip price so it never decreases mid-ride.
    func changeDestination(to place: NearbyPlace) async {
        guard let origin = currentRouteOrigin else { return }

        let isRideActive = simulationEngine.isRunning || simulationEngine.isPaused

        // Capture distance driven in the current segment before resetting.
        if isRideActive {
            if originalTripPrice == nil {
                originalTripPrice = estimatedPrice
                originalTripDistance = tripInfo?.distance
            }
            accumulatedDrivenDistance += simulationEngine.distanceTraveled
        }

        destinationName = place.name
        destinationAddress = place.address
        destination = place.coordinate

        do {
            let calculatedRoute = try await routeService.calculateRoute(
                from: origin,
                to: place.coordinate
            )
            route = calculatedRoute

            // For an active ride, the effective distance is total driven + remaining,
            // floored at the original trip distance so the price never drops.
            let effectiveDistance: CLLocationDistance
            if isRideActive {
                let originalDistance = originalTripDistance ?? calculatedRoute.distance
                effectiveDistance = max(
                    accumulatedDrivenDistance + calculatedRoute.distance,
                    originalDistance
                )
            } else {
                effectiveDistance = calculatedRoute.distance
            }

            tripInfo = TripInfo(
                distance: effectiveDistance,
                expectedTravelTime: calculatedRoute.expectedTravelTime,
                routeName: calculatedRoute.name
            )

            // Zoom camera to show the new route.
            let mapRect = calculatedRoute.polyline.boundingMapRect
            let paddedRect = mapRect.insetBy(
                dx: -mapRect.size.width * 0.3,
                dy: -mapRect.size.height * 0.3
            )
            cameraPosition = .region(MKCoordinateRegion(paddedRect))

            // If the ride simulation is running or paused, restart it with the new route.
            if isRideActive {
                simulationEngine.reset()
                beginRideSimulation(with: calculatedRoute)
            } else {
                simulationState = .routeReady
            }
        } catch {
            simulationState = .error(error.localizedDescription)
        }
    }

    func resetTrip() {
        simulationEngine.reset()
        pickupSimulationEngine.reset()
        pickupApproachTask?.cancel()
        pickupApproachTask = nil
        pickupRoute = nil
        pickupCarPosition = nil
        pickupStopLocation = nil
        destination = nil
        destinationName = nil
        destinationAddress = nil
        pickupAddress = nil
        rideStartDate = nil
        route = nil
        tripInfo = nil
        cameraPosition = .userLocation(fallback: .automatic)
        isTrunkOpen = false
        dropOffLocation = nil
        accumulatedDrivenDistance = 0
        originalTripDistance = nil
        originalTripPrice = nil
        simulationState = .selectingDestination
    }

    func dismissError() {
        simulationState = .selectingDestination
        destination = nil
    }
}
