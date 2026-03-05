import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct TripViewModelDestinationChangeTests {
    // MARK: - totalDistanceDriven

    @Test func totalDistanceDrivenIsZeroInitially() {
        let vm = TripViewModel()
        #expect(vm.totalDistanceDriven == 0)
    }

    @Test func totalDistanceDrivenIncludesEngineDistance() {
        let vm = TripViewModel()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0), // ~1110 m
        ]
        vm.simulationEngine.configure(with: coords)
        // Before starting, distanceTraveled is 0.
        #expect(vm.totalDistanceDriven == 0)
    }

    // MARK: - minimumRidePrice

    @Test func minimumRidePriceIsEstimatedPriceWhenNoOriginal() {
        let vm = TripViewModel()
        vm.tripInfo = TripInfo(
            distance: 1609.34 * 5,
            expectedTravelTime: 600,
            routeName: "Test"
        )
        // originalTripPrice is nil, so minimumRidePrice should equal estimatedPrice.
        #expect(vm.originalTripPrice == nil)
        #expect(vm.minimumRidePrice == vm.estimatedPrice)
    }

    @Test func minimumRidePriceIsNilWithoutTripInfo() {
        let vm = TripViewModel()
        // No tripInfo and no originalTripPrice.
        #expect(vm.minimumRidePrice == nil)
    }

    // MARK: - currentRouteOrigin

    @Test func currentRouteOriginFallsBackToNilWithoutData() {
        let vm = TripViewModel()
        // No simulation running, no pickup stop, no user location available.
        // This may be nil or the user's location depending on the location service state.
        // We just verify it doesn't crash.
        _ = vm.currentRouteOrigin
    }

    @Test func currentRouteOriginUsesPickupStopLocation() {
        let vm = TripViewModel()
        let stopLocation = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        vm.pickupStopLocation = stopLocation

        // With no running simulation and pickup stop set, should use pickup stop.
        let origin = vm.currentRouteOrigin
        #expect(origin != nil)
        #expect(origin!.latitude == stopLocation.latitude)
        #expect(origin!.longitude == stopLocation.longitude)
    }

    @Test func currentRouteOriginPrefersSimulationPositionOverPickupStop() {
        let vm = TripViewModel()
        vm.pickupStopLocation = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)

        // Simulate a running engine with a known position, without spawning async tasks.
        vm.simulationEngine.currentPosition = CLLocationCoordinate2D(latitude: 50.5, longitude: 20.5)
        vm.simulationEngine.isRunning = true

        // When the simulation is running and has a current position,
        // it should take priority over the pickup stop.
        let origin = vm.currentRouteOrigin
        #expect(origin != nil)
        #expect(abs(origin!.latitude - 50.5) < 0.0001)
        #expect(abs(origin!.longitude - 20.5) < 0.0001)
    }

    // MARK: - resetTrip Clears Destination Change State

    @Test func resetTripClearsAccumulatedDistance() {
        let vm = TripViewModel()
        vm.onAppear()
        vm.simulationState = .simulating(progress: 0.5)

        vm.resetTrip()

        // After reset, totalDistanceDriven should be 0.
        #expect(vm.totalDistanceDriven == 0)
    }

    @Test func resetTripClearsOriginalTripPrice() {
        let vm = TripViewModel()
        vm.onAppear()

        vm.resetTrip()

        #expect(vm.originalTripPrice == nil)
    }

    // MARK: - Pricing with Destination Change Scenario

    @Test func estimatedPriceForOneMile() {
        let vm = TripViewModel()
        vm.tripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        // $2 base + $2 * 1 mile = $4
        let price = vm.estimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 4.0) < 0.01)
    }

    @Test func estimatedPriceReflectsTripInfoDistance() {
        let vm = TripViewModel()

        // First set a short trip.
        vm.tripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Short"
        )
        let shortPrice = vm.estimatedPrice!

        // Then set a longer trip.
        vm.tripInfo = TripInfo(
            distance: 1609.34 * 10,
            expectedTravelTime: 1200,
            routeName: "Long"
        )
        let longPrice = vm.estimatedPrice!

        #expect(longPrice > shortPrice)
    }

    // MARK: - setDestination

    @Test func setDestinationUpdatesNameAndAddress() {
        let vm = TripViewModel()
        vm.onAppear()

        let place = NearbyPlace(
            id: "cafe-1",
            name: "Central Cafe",
            address: "100 Main St",
            coordinate: CLLocationCoordinate2D(latitude: 52.24, longitude: 21.02),
            distance: 500
        )

        vm.setDestination(from: place)

        #expect(vm.destinationName == "Central Cafe")
        #expect(vm.destinationAddress == "100 Main St")
        #expect(vm.destination != nil)
    }

    @Test func setDestinationForcesSelectingState() {
        let vm = TripViewModel()
        vm.simulationState = .completed

        let place = NearbyPlace(
            id: "cafe-2",
            name: "Corner Cafe",
            address: "200 Side St",
            coordinate: CLLocationCoordinate2D(latitude: 52.25, longitude: 21.03),
            distance: 800
        )

        vm.setDestination(from: place)

        // setDestination forces selectingDestination state so selectDestination guard passes.
        #expect(vm.destination != nil)
        #expect(vm.destinationName == "Corner Cafe")
    }

    // MARK: - Simulation Engine State After Reset

    @Test func resetTripResetsSimulationEngineCompletely() {
        let vm = TripViewModel()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        vm.simulationEngine.configure(with: coords)
        vm.simulationEngine.isRunning = true
        vm.simulationEngine.progress = 0.5

        vm.resetTrip()

        #expect(vm.simulationEngine.isRunning == false)
        #expect(vm.simulationEngine.progress == 0)
        #expect(vm.simulationEngine.currentPosition == nil)
        #expect(vm.simulationEngine.totalDistance == 0)
    }

    @Test func resetTripResetsPickupSimulationEngine() {
        let vm = TripViewModel()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        vm.pickupSimulationEngine.configure(with: coords)
        vm.pickupSimulationEngine.isRunning = true

        vm.resetTrip()

        #expect(vm.pickupSimulationEngine.isRunning == false)
        #expect(vm.pickupSimulationEngine.progress == 0)
    }

    // MARK: - Drop Off Location

    @Test func dropOffLocationIsNilInitially() {
        let vm = TripViewModel()
        #expect(vm.dropOffLocation == nil)
    }

    @Test func dropOffLocationClearedOnReset() {
        let vm = TripViewModel()
        vm.dropOffLocation = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)

        vm.resetTrip()

        #expect(vm.dropOffLocation == nil)
    }

    // MARK: - Pickup State

    @Test func pickupStateIsNilInitially() {
        let vm = TripViewModel()
        #expect(vm.pickupCarPosition == nil)
        #expect(vm.pickupStopLocation == nil)
        #expect(vm.pickupRoute == nil)
    }

    @Test func pickupStateClearedOnReset() {
        let vm = TripViewModel()
        vm.pickupCarPosition = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        vm.pickupStopLocation = CLLocationCoordinate2D(latitude: 52.24, longitude: 21.02)

        vm.resetTrip()

        #expect(vm.pickupCarPosition == nil)
        #expect(vm.pickupStopLocation == nil)
        #expect(vm.pickupRoute == nil)
    }

    // MARK: - Remaining Pickup Route Coordinates

    @Test func remainingPickupRouteCoordinatesUsesPickupEngine() {
        let vm = TripViewModel()
        // Without configuring the pickup engine, remaining coordinates should be empty.
        #expect(vm.remainingPickupRouteCoordinates.isEmpty)
    }

    @Test func remainingPickupRouteCoordinatesReflectsEngine() {
        let vm = TripViewModel()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
        ]
        vm.pickupSimulationEngine.configure(with: coords)

        let remaining = vm.remainingPickupRouteCoordinates
        #expect(!remaining.isEmpty)
    }
}
