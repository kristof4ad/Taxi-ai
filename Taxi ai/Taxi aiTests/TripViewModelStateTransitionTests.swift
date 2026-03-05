import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct TripViewModelStateTransitionTests {
    // MARK: - Initial State

    @Test func startsInIdleState() {
        let vm = TripViewModel()
        #expect(vm.simulationState == .idle)
        #expect(vm.destination == nil)
        #expect(vm.route == nil)
        #expect(vm.tripInfo == nil)
        #expect(vm.destinationName == nil)
        #expect(vm.destinationAddress == nil)
        #expect(vm.pickupAddress == nil)
        #expect(vm.rideStartDate == nil)
        #expect(vm.dropOffLocation == nil)
        #expect(vm.isTrunkOpen == false)
    }

    // MARK: - onAppear Transitions

    @Test func onAppearTransitionsFromIdleToSelecting() {
        let vm = TripViewModel()
        vm.onAppear()
        #expect(vm.simulationState == .selectingDestination)
    }

    @Test func multipleOnAppearCallsStayInSelecting() {
        let vm = TripViewModel()
        vm.onAppear()
        vm.onAppear()
        #expect(vm.simulationState == .selectingDestination)
    }

    // MARK: - selectDestination Guards

    @Test func selectDestinationIgnoredInIdleState() {
        let vm = TripViewModel()
        let coord = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        vm.selectDestination(coord)
        #expect(vm.destination == nil)
    }

    @Test func selectDestinationSetsCoordinateWhenSelecting() {
        let vm = TripViewModel()
        vm.onAppear()
        let coord = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        vm.selectDestination(coord)

        #expect(vm.destination != nil)
        #expect(vm.destination!.latitude == coord.latitude)
        #expect(vm.destination!.longitude == coord.longitude)
    }

    @Test func selectDestinationIgnoredDuringRouteReady() {
        let vm = TripViewModel()
        vm.onAppear()

        // Manually set state to routeReady to bypass route calculation.
        vm.simulationState = .routeReady
        let existingDestination = vm.destination

        let newCoord = CLLocationCoordinate2D(latitude: 50.0, longitude: 19.0)
        vm.selectDestination(newCoord)

        // Destination should not change since state isn't selectingDestination.
        #expect(vm.destination?.latitude == existingDestination?.latitude)
    }

    // MARK: - startSimulation Guards

    @Test func startSimulationIgnoredInIdleState() {
        let vm = TripViewModel()
        vm.startSimulation()
        #expect(vm.simulationState == .idle)
    }

    @Test func startSimulationIgnoredInSelectingState() {
        let vm = TripViewModel()
        vm.onAppear()
        vm.startSimulation()
        #expect(vm.simulationState == .selectingDestination)
    }

    @Test func startSimulationIgnoredInCalculatingState() {
        let vm = TripViewModel()
        vm.simulationState = .calculatingRoute
        vm.startSimulation()
        #expect(vm.simulationState == .calculatingRoute)
    }

    @Test func startSimulationIgnoredWhenRouteIsNil() {
        let vm = TripViewModel()
        vm.simulationState = .routeReady
        // route is nil, so startSimulation should do nothing.
        vm.startSimulation()
        #expect(vm.simulationState == .routeReady)
    }

    // MARK: - canStartSimulation Computed Property

    @Test func canStartSimulationOnlyInRouteReady() {
        let vm = TripViewModel()

        vm.simulationState = .idle
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .selectingDestination
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .calculatingRoute
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .routeReady
        #expect(vm.canStartSimulation == true)

        vm.simulationState = .approachingPickup(progress: 0.5)
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .arrivedAtPickup
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .simulating(progress: 0.5)
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .completed
        #expect(vm.canStartSimulation == false)

        vm.simulationState = .error("test")
        #expect(vm.canStartSimulation == false)
    }

    // MARK: - showControlPanel Computed Property

    @Test func showControlPanelForCorrectStates() {
        let vm = TripViewModel()

        vm.simulationState = .idle
        #expect(vm.showControlPanel == false)

        vm.simulationState = .selectingDestination
        #expect(vm.showControlPanel == false)

        vm.simulationState = .calculatingRoute
        #expect(vm.showControlPanel == false)

        vm.simulationState = .routeReady
        #expect(vm.showControlPanel == true)

        vm.simulationState = .simulating(progress: 0.5)
        #expect(vm.showControlPanel == true)

        vm.simulationState = .completed
        #expect(vm.showControlPanel == true)

        vm.simulationState = .approachingPickup(progress: 0.3)
        #expect(vm.showControlPanel == false)

        vm.simulationState = .arrivedAtPickup
        #expect(vm.showControlPanel == false)

        vm.simulationState = .error("test")
        #expect(vm.showControlPanel == false)
    }

    // MARK: - Error State

    @Test func errorMessageExtractsFromErrorState() {
        let vm = TripViewModel()
        vm.simulationState = .error("Route not found")
        #expect(vm.errorMessage == "Route not found")
    }

    @Test func errorMessageIsNilForNonErrorStates() {
        let vm = TripViewModel()

        vm.simulationState = .idle
        #expect(vm.errorMessage == nil)

        vm.simulationState = .selectingDestination
        #expect(vm.errorMessage == nil)

        vm.simulationState = .simulating(progress: 0.5)
        #expect(vm.errorMessage == nil)
    }

    @Test func dismissErrorResetsToSelecting() {
        let vm = TripViewModel()
        vm.simulationState = .error("Something went wrong")
        vm.destination = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)

        vm.dismissError()

        #expect(vm.simulationState == .selectingDestination)
        #expect(vm.destination == nil)
    }

    // MARK: - resetTrip

    @Test func resetTripClearsAllState() {
        let vm = TripViewModel()
        vm.onAppear()

        // Set various state to simulate an in-progress trip.
        vm.destination = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        vm.destinationName = "Test Place"
        vm.destinationAddress = "123 Test St"
        vm.isTrunkOpen = true
        vm.simulationState = .simulating(progress: 0.5)

        vm.resetTrip()

        #expect(vm.simulationState == .selectingDestination)
        #expect(vm.destination == nil)
        #expect(vm.destinationName == nil)
        #expect(vm.destinationAddress == nil)
        #expect(vm.pickupAddress == nil)
        #expect(vm.rideStartDate == nil)
        #expect(vm.route == nil)
        #expect(vm.tripInfo == nil)
        #expect(vm.isTrunkOpen == false)
        #expect(vm.dropOffLocation == nil)
        #expect(vm.pickupCarPosition == nil)
        #expect(vm.pickupStopLocation == nil)
        #expect(vm.pickupRoute == nil)
        #expect(vm.originalTripPrice == nil)
    }

    @Test func resetTripStopsSimulationEngine() {
        let vm = TripViewModel()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        vm.simulationEngine.configure(with: coords)
        vm.simulationEngine.start()

        vm.resetTrip()

        #expect(vm.simulationEngine.isRunning == false)
        #expect(vm.simulationEngine.progress == 0)
        #expect(vm.simulationEngine.currentPosition == nil)
    }

    @Test func resetTripStopsPickupSimulationEngine() {
        let vm = TripViewModel()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        vm.pickupSimulationEngine.configure(with: coords)
        vm.pickupSimulationEngine.start()

        vm.resetTrip()

        #expect(vm.pickupSimulationEngine.isRunning == false)
        #expect(vm.pickupSimulationEngine.progress == 0)
    }

    // MARK: - setDestination

    @Test func setDestinationUpdatesNameAndAddress() {
        let vm = TripViewModel()
        vm.onAppear()

        let place = NearbyPlace(
            id: "test-1",
            name: "Coffee Shop",
            address: "456 Brew Ave",
            coordinate: CLLocationCoordinate2D(latitude: 52.24, longitude: 21.02),
            distance: 500
        )

        vm.setDestination(from: place)

        #expect(vm.destinationName == "Coffee Shop")
        #expect(vm.destinationAddress == "456 Brew Ave")
        #expect(vm.destination != nil)
        #expect(vm.destination!.latitude == 52.24)
    }

    @Test func setDestinationTransitionsToSelectingFirst() {
        let vm = TripViewModel()
        // Start in idle — setDestination should force state to selectingDestination
        // so selectDestination's guard passes.
        vm.simulationState = .routeReady

        let place = NearbyPlace(
            id: "test-2",
            name: "Restaurant",
            address: "789 Food St",
            coordinate: CLLocationCoordinate2D(latitude: 52.25, longitude: 21.03),
            distance: 800
        )

        vm.setDestination(from: place)

        // Should have set destination (since setDestination forces selectingDestination state).
        #expect(vm.destination != nil)
        #expect(vm.destinationName == "Restaurant")
    }

    // MARK: - SimulationState Equality

    @Test func simulationStateProgressEquality() {
        // Ensure progress values are compared correctly.
        let state1 = SimulationState.simulating(progress: 0.5)
        let state2 = SimulationState.simulating(progress: 0.5)
        let state3 = SimulationState.simulating(progress: 0.7)

        #expect(state1 == state2)
        #expect(state1 != state3)
    }

    @Test func simulationStateApproachingPickupEquality() {
        let state1 = SimulationState.approachingPickup(progress: 0.3)
        let state2 = SimulationState.approachingPickup(progress: 0.3)
        let state3 = SimulationState.approachingPickup(progress: 0.9)

        #expect(state1 == state2)
        #expect(state1 != state3)
    }

    @Test func simulationStateErrorEquality() {
        let state1 = SimulationState.error("Error A")
        let state2 = SimulationState.error("Error A")
        let state3 = SimulationState.error("Error B")

        #expect(state1 == state2)
        #expect(state1 != state3)
    }

    @Test func differentSimulationStatesAreNotEqual() {
        #expect(SimulationState.idle != SimulationState.selectingDestination)
        #expect(SimulationState.routeReady != SimulationState.completed)
        #expect(SimulationState.simulating(progress: 0.5) != SimulationState.approachingPickup(progress: 0.5))
    }

    // MARK: - Location Denied

    @Test func locationDeniedDefaultsToFalse() {
        let vm = TripViewModel()
        // Fresh LocationService should not be denied.
        #expect(vm.locationDenied == false)
    }

    // MARK: - Drop Off Distance Constant

    @Test func dropOffDistanceIs100Meters() {
        #expect(TripViewModel.dropOffDistance == 100)
    }
}
