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

    // MARK: - State

    var simulationState: SimulationState = .idle
    var destination: CLLocationCoordinate2D?
    var destinationName: String?
    var destinationAddress: String?
    var route: MKRoute?
    var tripInfo: TripInfo?
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    // MARK: - Pickup Approach State

    /// The car's current position as it approaches the pickup.
    var pickupCarPosition: CLLocationCoordinate2D?
    /// The calculated route from the car's start position to the pickup.
    var pickupRoute: MKRoute?
    /// Dedicated simulation engine for the pickup approach (separate from trip simulation).
    let pickupSimulationEngine = SimulationEngine()
    private var pickupApproachTask: Task<Void, Never>?

    // MARK: - Services

    let locationService: LocationService
    let simulationEngine = SimulationEngine()
    private let routeService = RouteService()

    // MARK: - Init

    /// Creates a trip view model, optionally sharing a location service from the home screen.
    init(locationService: LocationService = LocationService()) {
        self.locationService = locationService
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

    /// Estimated trip price based on distance: $2 base + $2/mile.
    var estimatedPrice: Double? {
        guard let tripInfo else { return nil }
        let miles = Measurement(
            value: tripInfo.distance,
            unit: UnitLength.meters
        ).converted(to: .miles).value
        return Self.baseFare + Self.perMileRate * miles
    }

    /// Estimated arrival time at the destination.
    var estimatedArrivalTime: Date? {
        guard let tripInfo else { return nil }
        return Date.now.addingTimeInterval(tripInfo.expectedTravelTime)
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

    /// Starts the car approaching the pickup location along real roads from a random nearby position.
    func startPickupApproach() {
        guard let userLocation = locationService.userLocation else { return }

        let startPosition = randomNearbyPosition(around: userLocation)
        pickupCarPosition = startPosition
        simulationState = .approachingPickup(progress: 0)

        pickupApproachTask = Task {
            // Calculate a real driving route from the random start to the user's pickup.
            do {
                let approachRoute = try await routeService.calculateRoute(
                    from: startPosition,
                    to: userLocation
                )
                pickupRoute = approachRoute

                // Zoom camera to show the approach route area (car → pickup).
                let approachRect = approachRoute.polyline.boundingMapRect
                let paddedRect = approachRect.insetBy(
                    dx: -approachRect.size.width * 0.5,
                    dy: -approachRect.size.height * 0.5
                )
                cameraPosition = .region(MKCoordinateRegion(paddedRect))

                // Configure the pickup simulation engine and start it.
                let coordinates = approachRoute.coordinates
                pickupSimulationEngine.configure(with: coordinates)
                pickupSimulationEngine.start()

                // Monitor the engine's progress.
                while pickupSimulationEngine.isRunning {
                    if let position = pickupSimulationEngine.currentPosition {
                        pickupCarPosition = position
                    }
                    simulationState = .approachingPickup(progress: pickupSimulationEngine.progress)
                    try? await Task.sleep(for: .milliseconds(16))
                }

                pickupCarPosition = userLocation
                simulationState = .arrivedAtPickup
            } catch {
                // If route calculation fails, fall back to arrived state.
                pickupCarPosition = userLocation
                simulationState = .arrivedAtPickup
            }
        }
    }

    func startSimulation() {
        guard simulationState == .routeReady, let route else { return }

        let coordinates = route.coordinates
        simulationEngine.configure(with: coordinates)
        simulationEngine.start()
        simulationState = .simulating(progress: 0)

        // Monitor progress updates.
        Task {
            while simulationEngine.isRunning {
                simulationState = .simulating(progress: simulationEngine.progress)
                try? await Task.sleep(for: .milliseconds(100))
            }
            simulationState = .completed
        }
    }

    func resetTrip() {
        simulationEngine.reset()
        pickupSimulationEngine.reset()
        pickupApproachTask?.cancel()
        pickupApproachTask = nil
        pickupRoute = nil
        pickupCarPosition = nil
        destination = nil
        destinationName = nil
        destinationAddress = nil
        route = nil
        tripInfo = nil
        cameraPosition = .userLocation(fallback: .automatic)
        simulationState = .selectingDestination
    }

    func dismissError() {
        simulationState = .selectingDestination
        destination = nil
    }

    // MARK: - Pickup Approach Helpers

    /// Generates a random position ~1-2 km from the given coordinate in a random direction.
    private func randomNearbyPosition(
        around center: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let bearingRad = Double.random(in: 0..<(2 * .pi))
        let distance = Double.random(in: 800...1500)
        let lat = center.latitude + (distance / 111_320) * cos(bearingRad)
        let lon = center.longitude + (distance / (111_320 * cos(center.latitude * .pi / 180))) * sin(bearingRad)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Private

    private func calculateRoute() async {
        guard let origin = locationService.userLocation,
              let destination else { return }

        simulationState = .calculatingRoute

        do {
            let calculatedRoute = try await routeService.calculateRoute(
                from: origin,
                to: destination
            )
            route = calculatedRoute
            tripInfo = TripInfo(
                distance: calculatedRoute.distance,
                expectedTravelTime: calculatedRoute.expectedTravelTime,
                routeName: calculatedRoute.name
            )

            // Zoom camera to show the entire route.
            let mapRect = calculatedRoute.polyline.boundingMapRect
            let paddedRect = mapRect.insetBy(dx: -mapRect.size.width * 0.2, dy: -mapRect.size.height * 0.2)
            let region = MKCoordinateRegion(paddedRect)
            cameraPosition = .region(region)

            simulationState = .routeReady
        } catch {
            simulationState = .error(error.localizedDescription)
        }
    }
}
