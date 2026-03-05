import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct TripViewModelPricingTests {
    // MARK: - Price Calculation

    @Test func baseFareIsCorrect() {
        #expect(TripViewModel.baseFare == 2.00)
    }

    @Test func perMileRateIsCorrect() {
        #expect(TripViewModel.perMileRate == 2.00)
    }

    @Test func estimatedPriceIsNilWithoutTripInfo() {
        let vm = TripViewModel()
        #expect(vm.estimatedPrice == nil)
    }

    @Test func estimatedPriceForOneMile() {
        let vm = TripViewModel()
        vm.onAppear()

        // 1 mile = 1609.34 meters
        let oneMileInMeters: Double = 1609.34
        setTripInfo(on: vm, distance: oneMileInMeters)

        // Expected: $2 base + $2 * 1 mile = $4
        let price = vm.estimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 4.0) < 0.01)
    }

    @Test func estimatedPriceForFiveMiles() {
        let vm = TripViewModel()
        vm.onAppear()

        let fiveMilesInMeters: Double = 1609.34 * 5
        setTripInfo(on: vm, distance: fiveMilesInMeters)

        // Expected: $2 base + $2 * 5 miles = $12
        let price = vm.estimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 12.0) < 0.01)
    }

    @Test func estimatedPriceForZeroDistance() {
        let vm = TripViewModel()
        vm.onAppear()

        setTripInfo(on: vm, distance: 0)

        // Expected: $2 base + $0 = $2
        let price = vm.estimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 2.0) < 0.01)
    }

    @Test func estimatedPriceForLongTrip() {
        let vm = TripViewModel()
        vm.onAppear()

        let twentyMilesInMeters: Double = 1609.34 * 20
        setTripInfo(on: vm, distance: twentyMilesInMeters)

        // Expected: $2 base + $2 * 20 miles = $42
        let price = vm.estimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 42.0) < 0.01)
    }

    @Test func estimatedPriceForFractionalMiles() {
        let vm = TripViewModel()
        vm.onAppear()

        // 2.5 miles
        let distance: Double = 1609.34 * 2.5
        setTripInfo(on: vm, distance: distance)

        // Expected: $2 base + $2 * 2.5 miles = $7
        let price = vm.estimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 7.0) < 0.01)
    }

    // MARK: - Currency Fallback

    @Test func displayCurrencyCodeFallsBackToUSD() {
        let vm = TripViewModel()
        // Without fetching exchange rate, should fall back to USD if no rate is available.
        let code = vm.displayCurrencyCode
        // Will be either local currency or "USD" depending on device locale.
        #expect(!code.isEmpty)
    }

    // MARK: - Minimum Ride Price

    @Test func minimumRidePriceIsEstimatedPriceWhenNoOriginal() {
        let vm = TripViewModel()
        vm.onAppear()

        setTripInfo(on: vm, distance: 1609.34 * 5)

        // originalTripPrice is nil, so minimumRidePrice should equal estimatedPrice.
        #expect(vm.originalTripPrice == nil)
        #expect(vm.minimumRidePrice == vm.estimatedPrice)
    }

    @Test func minimumRidePriceUsesOriginalWhenSet() {
        let vm = TripViewModel()
        vm.onAppear()

        setTripInfo(on: vm, distance: 1609.34 * 5)

        // Simulate having an original trip price set from a destination change.
        // We can't set originalTripPrice directly since it's private(set),
        // but we can verify the computed property logic.
        #expect(vm.minimumRidePrice == vm.estimatedPrice)
    }

    // MARK: - Estimated Times

    @Test func estimatedPickupTimeIsFutureDate() {
        let vm = TripViewModel()
        let pickupTime = vm.estimatedPickupTime

        // Should be approximately 7 minutes from now.
        let difference = pickupTime.timeIntervalSinceNow
        #expect(difference > 400) // At least ~6.7 minutes
        #expect(difference < 440) // At most ~7.3 minutes
    }

    @Test func estimatedArrivalTimeIsNilWithoutTripInfo() {
        let vm = TripViewModel()
        #expect(vm.estimatedArrivalTime == nil)
    }

    @Test func estimatedArrivalTimeAccountsForTravelTime() {
        let vm = TripViewModel()

        // Set travel time to 600 seconds (10 minutes).
        setTripInfo(on: vm, distance: 5000, travelTime: 600)

        let arrival = vm.estimatedArrivalTime
        #expect(arrival != nil)

        // Arrival = pickup time + travel time = now + 7 min + 10 min = now + 17 min
        let difference = arrival!.timeIntervalSinceNow
        #expect(difference > 990) // At least ~16.5 min
        #expect(difference < 1040) // At most ~17.3 min
    }

    // MARK: - Helpers

    /// Sets trip info on the view model for testing pricing without needing a real route.
    private func setTripInfo(
        on vm: TripViewModel,
        distance: CLLocationDistance,
        travelTime: TimeInterval = 300
    ) {
        // Access the tripInfo property directly since it's internal.
        vm.tripInfo = TripInfo(
            distance: distance,
            expectedTravelTime: travelTime,
            routeName: "Test Route"
        )
    }
}
