import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct EditTripViewModelPricingTests {
    // MARK: - Helpers

    /// Creates an EditTripViewModel with controlled dependencies for testing pricing logic.
    private func makeViewModel(
        originalPrice: Double? = nil,
        routeOrigin: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
        distanceAlreadyDriven: CLLocationDistance = 0,
        minimumPrice: Double? = nil
    ) -> EditTripViewModel {
        EditTripViewModel(
            locationService: LocationService(),
            currencyService: CurrencyService(),
            originalPrice: originalPrice,
            routeOrigin: routeOrigin,
            distanceAlreadyDriven: distanceAlreadyDriven,
            minimumPrice: minimumPrice
        )
    }

    // MARK: - newEstimatedPrice

    @Test func newEstimatedPriceIsNilWithoutTripInfo() {
        let vm = makeViewModel()
        #expect(vm.newEstimatedPrice == nil)
    }

    @Test func newEstimatedPriceCalculatesFromTripInfo() {
        let vm = makeViewModel()
        // 1 mile = 1609.34 m
        vm.newTripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        // Expected: $2 base + $2 * 1 mile = $4 (in USD, no exchange rate set)
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 4.0) < 0.01)
    }

    @Test func newEstimatedPriceIncludesDistanceAlreadyDriven() {
        let oneMile = 1609.34
        let vm = makeViewModel(distanceAlreadyDriven: oneMile)
        // New route is 1 mile, but already driven 1 mile → total 2 miles
        vm.newTripInfo = TripInfo(
            distance: oneMile,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        // Expected: $2 base + $2 * 2 miles = $6
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 6.0) < 0.01)
    }

    @Test func newEstimatedPriceEnforcesMinimumPrice() {
        let vm = makeViewModel(
            distanceAlreadyDriven: 0,
            minimumPrice: 10.0
        )
        // Short route: 0.5 miles → $2 + $1 = $3, but minimum is $10
        vm.newTripInfo = TripInfo(
            distance: 1609.34 * 0.5,
            expectedTravelTime: 100,
            routeName: "Test"
        )
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(price! == 10.0)
    }

    @Test func newEstimatedPriceExceedsMinimumWhenHigher() {
        let vm = makeViewModel(
            distanceAlreadyDriven: 0,
            minimumPrice: 3.0
        )
        // 5 miles → $2 + $10 = $12, well above $3 minimum
        vm.newTripInfo = TripInfo(
            distance: 1609.34 * 5,
            expectedTravelTime: 600,
            routeName: "Test"
        )
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 12.0) < 0.01)
    }

    @Test func newEstimatedPriceWithZeroDistance() {
        let vm = makeViewModel()
        vm.newTripInfo = TripInfo(
            distance: 0,
            expectedTravelTime: 0,
            routeName: "Test"
        )
        // Expected: $2 base only
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 2.0) < 0.01)
    }

    @Test func newEstimatedPriceWithLargeDistanceAlreadyDriven() {
        let oneMile = 1609.34
        let vm = makeViewModel(distanceAlreadyDriven: oneMile * 10)
        // New route is 5 miles, already driven 10 miles → total 15 miles
        vm.newTripInfo = TripInfo(
            distance: oneMile * 5,
            expectedTravelTime: 900,
            routeName: "Test"
        )
        // Expected: $2 + $2 * 15 = $32
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 32.0) < 0.01)
    }

    // MARK: - priceDifference

    @Test func priceDifferenceIsNilWithoutNewPrice() {
        let vm = makeViewModel(originalPrice: 10.0)
        // No newTripInfo set, so newEstimatedPrice is nil.
        #expect(vm.priceDifference == nil)
    }

    @Test func priceDifferenceIsNilWithoutOriginalPrice() {
        let vm = makeViewModel(originalPrice: nil)
        vm.newTripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        #expect(vm.priceDifference == nil)
    }

    @Test func priceDifferenceCalculatesPositiveIncrease() {
        let vm = makeViewModel(originalPrice: 4.0)
        // 5 miles → $12
        vm.newTripInfo = TripInfo(
            distance: 1609.34 * 5,
            expectedTravelTime: 600,
            routeName: "Test"
        )
        let diff = vm.priceDifference
        #expect(diff != nil)
        #expect(abs(diff! - 8.0) < 0.01) // $12 - $4 = $8
    }

    @Test func priceDifferenceCalculatesNegativeDecrease() {
        let vm = makeViewModel(originalPrice: 12.0)
        // 1 mile → $4
        vm.newTripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        let diff = vm.priceDifference
        #expect(diff != nil)
        #expect(abs(diff! - (-8.0)) < 0.01) // $4 - $12 = -$8
    }

    @Test func priceDifferenceIsZeroForSamePrice() {
        // Original price $4, new route 1 mile → $4
        let vm = makeViewModel(originalPrice: 4.0)
        vm.newTripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        let diff = vm.priceDifference
        #expect(diff != nil)
        #expect(abs(diff!) < 0.01)
    }

    // MARK: - displayCurrencyCode

    @Test func displayCurrencyCodeIsNotEmpty() {
        let vm = makeViewModel()
        #expect(!vm.displayCurrencyCode.isEmpty)
    }

    // MARK: - clearSearch

    @Test func clearSearchResetsState() {
        let vm = makeViewModel()
        vm.searchText = "Coffee"
        vm.isSearchActive = true
        vm.newDestination = NearbyPlace(
            id: "test",
            name: "Test",
            address: "123 Test",
            coordinate: CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
            distance: 100
        )
        vm.newTripInfo = TripInfo(
            distance: 1000,
            expectedTravelTime: 60,
            routeName: "Test"
        )
        vm.showPriceConfirmation = true

        vm.clearSearch()

        #expect(vm.searchText == "")
        #expect(vm.isSearchActive == false)
        #expect(vm.selectedDestination == nil)
        #expect(vm.newDestination == nil)
        #expect(vm.newRoute == nil)
        #expect(vm.newTripInfo == nil)
        #expect(vm.showPriceConfirmation == false)
    }

    // MARK: - Initial State

    @Test func initialStateIsClean() {
        let vm = makeViewModel()

        #expect(vm.searchText == "")
        #expect(vm.isSearchActive == false)
        #expect(vm.selectedDestination == nil)
        #expect(vm.newDestination == nil)
        #expect(vm.newRoute == nil)
        #expect(vm.newTripInfo == nil)
        #expect(vm.isCalculatingRoute == false)
        #expect(vm.showPriceConfirmation == false)
        #expect(vm.showTooFarAlert == false)
        #expect(vm.nearbyPlaces.isEmpty)
    }

    // MARK: - Minimum Price Edge Cases

    @Test func minimumPriceNilAllowsAnyPrice() {
        let vm = makeViewModel(minimumPrice: nil)
        // Very short route → cheap price
        vm.newTripInfo = TripInfo(
            distance: 100, // ~0.06 miles
            expectedTravelTime: 10,
            routeName: "Test"
        )
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        // $2 base + small per-mile, no minimum enforcement
        #expect(price! < 3.0)
    }

    @Test func minimumPriceOfZeroHasNoEffect() {
        let vm = makeViewModel(minimumPrice: 0)
        vm.newTripInfo = TripInfo(
            distance: 1609.34,
            expectedTravelTime: 300,
            routeName: "Test"
        )
        // $4 > $0 minimum, so max returns $4
        let price = vm.newEstimatedPrice
        #expect(price != nil)
        #expect(abs(price! - 4.0) < 0.01)
    }
}
