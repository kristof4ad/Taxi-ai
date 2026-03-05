import CoreLocation
import Testing

@testable import Taxi_ai

/// Integration tests that verify multi-step workflows across multiple components.
@MainActor
struct RideFlowIntegrationTests {
    // MARK: - Full Reset Flow

    @Test func fullResetClearsAllComponents() {
        let vm = TripViewModel()
        vm.onAppear()

        // Simulate setting up a trip with various state.
        vm.destination = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        vm.destinationName = "Airport"
        vm.destinationAddress = "123 Airport Rd"
        vm.isTrunkOpen = true
        vm.dropOffLocation = CLLocationCoordinate2D(latitude: 52.24, longitude: 21.02)
        vm.pickupCarPosition = CLLocationCoordinate2D(latitude: 52.22, longitude: 21.00)
        vm.pickupStopLocation = CLLocationCoordinate2D(latitude: 52.225, longitude: 21.005)
        vm.tripInfo = TripInfo(distance: 5000, expectedTravelTime: 600, routeName: "Test")
        vm.simulationState = .simulating(progress: 0.5)

        // Configure both engines.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        vm.simulationEngine.configure(with: coords)
        vm.pickupSimulationEngine.configure(with: coords)

        // Reset everything.
        vm.resetTrip()

        // Verify TripViewModel state.
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

        // Verify SimulationEngine state.
        #expect(vm.simulationEngine.isRunning == false)
        #expect(vm.simulationEngine.isPaused == false)
        #expect(vm.simulationEngine.progress == 0)
        #expect(vm.simulationEngine.currentPosition == nil)
        #expect(vm.simulationEngine.totalDistance == 0)

        // Verify pickup engine state.
        #expect(vm.pickupSimulationEngine.isRunning == false)
        #expect(vm.pickupSimulationEngine.progress == 0)
    }

    // MARK: - Destination Selection Flow

    @Test func selectDestinationFromNearbyPlaceFlow() {
        let vm = TripViewModel()
        vm.onAppear()

        let place = NearbyPlace(
            id: "restaurant-1",
            name: "Italian Restaurant",
            address: "456 Pasta Lane",
            coordinate: CLLocationCoordinate2D(latitude: 52.24, longitude: 21.02),
            distance: 750
        )

        vm.setDestination(from: place)

        #expect(vm.destinationName == "Italian Restaurant")
        #expect(vm.destinationAddress == "456 Pasta Lane")
        #expect(vm.destination != nil)
        #expect(vm.destination!.latitude == 52.24)
        #expect(vm.destination!.longitude == 21.02)
    }

    @Test func selectDestinationThenResetThenSelectAgain() {
        let vm = TripViewModel()
        vm.onAppear()

        // First selection.
        let place1 = NearbyPlace(
            id: "p1",
            name: "First Place",
            address: "111 First St",
            coordinate: CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
            distance: 500
        )
        vm.setDestination(from: place1)
        #expect(vm.destinationName == "First Place")

        // Reset.
        vm.resetTrip()
        #expect(vm.destinationName == nil)
        #expect(vm.destination == nil)

        // Second selection.
        let place2 = NearbyPlace(
            id: "p2",
            name: "Second Place",
            address: "222 Second St",
            coordinate: CLLocationCoordinate2D(latitude: 52.25, longitude: 21.03),
            distance: 1000
        )
        vm.setDestination(from: place2)
        #expect(vm.destinationName == "Second Place")
        #expect(vm.destination!.latitude == 52.25)
    }

    // MARK: - Pricing Integration

    @Test func pricingReflectsDestinationDistance() {
        let vm = TripViewModel()
        vm.onAppear()

        // Short trip: 1 mile.
        vm.tripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Short Route"
        )
        let shortPrice = vm.estimatedPrice!

        // Long trip: 10 miles.
        vm.tripInfo = TripInfo(
            distance: 1609.34 * 10,
            expectedTravelTime: 1200,
            routeName: "Long Route"
        )
        let longPrice = vm.estimatedPrice!

        #expect(longPrice > shortPrice)
        // Short: $4, Long: $22.
        #expect(abs(shortPrice - 4.0) < 0.01)
        #expect(abs(longPrice - 22.0) < 0.01)
    }

    @Test func editTripPricingMatchesTripViewModelPricing() {
        // Verify that EditTripViewModel and TripViewModel produce consistent prices
        // for the same distance.
        let tripVM = TripViewModel()
        tripVM.tripInfo = TripInfo(
            distance: 1609.34 * 5,
            expectedTravelTime: 600,
            routeName: "Test"
        )
        let tripPrice = tripVM.estimatedPrice!

        let editVM = EditTripViewModel(
            locationService: LocationService(),
            currencyService: CurrencyService(),
            originalPrice: nil,
            routeOrigin: CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
            distanceAlreadyDriven: 0
        )
        editVM.newTripInfo = TripInfo(
            distance: 1609.34 * 5,
            expectedTravelTime: 600,
            routeName: "Test"
        )
        let editPrice = editVM.newEstimatedPrice!

        // Both should calculate the same price for the same distance.
        #expect(abs(tripPrice - editPrice) < 0.01)
    }

    // MARK: - SimulationEngine + TripViewModel Integration

    @Test func simulationEngineConfigureAndResetCycle() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]

        // Configure → verify → reset → verify → reconfigure → verify.
        engine.configure(with: coords)
        #expect(engine.totalDistance > 1000)

        engine.reset()
        #expect(engine.totalDistance == 0)
        #expect(engine.currentPosition == nil)

        engine.configure(with: coords)
        #expect(engine.totalDistance > 1000)
    }

    // MARK: - Rating Integration

    @Test func rateRideViewModelProducesValidRating() {
        let vm = RateRideViewModel(ridePrice: 25.0, currencyCode: "USD")
        vm.starRating = 4
        vm.feedbackText = "Good service"
        vm.selectedTipPercentage = 20

        let rating = vm.buildRating()

        #expect(rating.starRating == 4)
        #expect(rating.feedbackText == "Good service")
        #expect(rating.tipPercentage == 20)
        #expect(abs(rating.tipAmount! - 5.0) < 0.01) // 20% of $25
    }

    @Test func ratingCanBeStoredInCompletedRide() throws {
        let vm = RateRideViewModel(ridePrice: 20.0, currencyCode: "USD")
        vm.starRating = 5
        vm.feedbackText = "Perfect!"
        vm.selectedTipPercentage = 30

        let rating = vm.buildRating()

        let ride = CompletedRide(
            date: .now,
            pickupName: "Home",
            destinationName: "Office",
            price: 20.0,
            currencyCode: "USD",
            starRating: rating.starRating,
            feedbackText: rating.feedbackText,
            tipPercentage: rating.tipPercentage,
            tipAmount: rating.tipAmount
        )

        #expect(ride.starRating == 5)
        #expect(ride.feedbackText == "Perfect!")
        #expect(ride.tipPercentage == 30)
        #expect(abs(ride.tipAmount! - 6.0) < 0.01) // 30% of $20
        #expect(abs(ride.totalPrice - 26.0) < 0.01) // $20 + $6 tip
    }

    // MARK: - State Machine Flow

    @Test func completeStateTransitionFlow() {
        let vm = TripViewModel()

        // Start in idle.
        #expect(vm.simulationState == .idle)

        // Appear → selecting.
        vm.onAppear()
        #expect(vm.simulationState == .selectingDestination)

        // Select destination (triggers route calculation async, but we can test the guard).
        #expect(vm.canStartSimulation == false)

        // Manually set to routeReady to test the next transition.
        vm.simulationState = .routeReady
        #expect(vm.canStartSimulation == true)
        #expect(vm.showControlPanel == true)

        // Without a route, startSimulation should be guarded.
        vm.startSimulation()
        #expect(vm.simulationState == .routeReady) // Stays because route is nil.

        // Set to completed to test panel visibility.
        vm.simulationState = .completed
        #expect(vm.showControlPanel == true)
        #expect(vm.canStartSimulation == false)

        // Error state.
        vm.simulationState = .error("Connection lost")
        #expect(vm.errorMessage == "Connection lost")
        #expect(vm.showControlPanel == false)

        // Dismiss error returns to selecting.
        vm.dismissError()
        #expect(vm.simulationState == .selectingDestination)
        #expect(vm.errorMessage == nil)
    }
}
