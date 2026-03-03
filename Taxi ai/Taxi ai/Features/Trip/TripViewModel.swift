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
