import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct HomeViewModelTests {
    // MARK: - Initial State

    @Test func initialStateIsClean() {
        let vm = HomeViewModel()

        #expect(vm.selectedCategory == .bars)
        #expect(vm.nearbyPlaces.isEmpty)
        #expect(vm.isSearching == false)
        #expect(vm.estimatedArrival == 5)
        #expect(vm.searchText == "")
        #expect(vm.isSearchActive == false)
        #expect(vm.selectedDestination == nil)
        #expect(vm.showTooFarAlert == false)
    }

    // MARK: - Max Distance

    @Test func maxDistanceIs30Miles() {
        #expect(HomeViewModel.maxDistanceMiles == 30)
    }

    // MARK: - Search Text

    @Test func updateSearchTextSetsText() {
        let vm = HomeViewModel()
        vm.updateSearchText("Coffee")
        #expect(vm.searchText == "Coffee")
    }

    @Test func updateSearchTextClearsCompletionsWhenEmpty() {
        let vm = HomeViewModel()
        vm.updateSearchText("Coffee")
        vm.updateSearchText("")

        #expect(vm.searchText == "")
        #expect(vm.currentCompletions.isEmpty)
    }

    // MARK: - Clear Search

    @Test func clearSearchResetsAllSearchState() {
        let vm = HomeViewModel()
        vm.searchText = "Test Query"
        vm.isSearchActive = true
        vm.selectedDestination = NearbyPlace(
            id: "test",
            name: "Test Place",
            address: "123 Test St",
            coordinate: CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
            distance: 500
        )

        vm.clearSearch()

        #expect(vm.searchText == "")
        #expect(vm.isSearchActive == false)
        #expect(vm.selectedDestination == nil)
        #expect(vm.currentCompletions.isEmpty)
    }

    // MARK: - Category Selection

    @Test func selectCategoryUpdatesSelected() {
        let vm = HomeViewModel()
        #expect(vm.selectedCategory == .bars)

        vm.selectCategory(.food)
        #expect(vm.selectedCategory == .food)

        vm.selectCategory(.shopping)
        #expect(vm.selectedCategory == .shopping)
    }

    @Test func selectCategoryAllCases() {
        let vm = HomeViewModel()
        for category in PlaceCategory.allCases {
            vm.selectCategory(category)
            #expect(vm.selectedCategory == category)
        }
    }

    // MARK: - Default Category

    @Test func defaultCategoryIsBars() {
        let vm = HomeViewModel()
        #expect(vm.selectedCategory == .bars)
    }

    // MARK: - Search Active State

    @Test func isSearchActiveDefaultsFalse() {
        let vm = HomeViewModel()
        #expect(vm.isSearchActive == false)
    }

    @Test func isSearchActiveCanBeToggled() {
        let vm = HomeViewModel()
        vm.isSearchActive = true
        #expect(vm.isSearchActive == true)

        vm.isSearchActive = false
        #expect(vm.isSearchActive == false)
    }

    // MARK: - Too Far Alert

    @Test func showTooFarAlertDefaultsFalse() {
        let vm = HomeViewModel()
        #expect(vm.showTooFarAlert == false)
    }

    // MARK: - Nearby Places

    @Test func nearbyPlacesStartsEmpty() {
        let vm = HomeViewModel()
        #expect(vm.nearbyPlaces.isEmpty)
    }

    // MARK: - Completions

    @Test func currentCompletionsStartsEmpty() {
        let vm = HomeViewModel()
        #expect(vm.currentCompletions.isEmpty)
    }

    // MARK: - Estimated Arrival

    @Test func estimatedArrivalDefaultsToFive() {
        let vm = HomeViewModel()
        #expect(vm.estimatedArrival == 5)
    }

    // MARK: - Search Without Location

    @Test func searchNearbyPlacesDoesNothingWithoutLocation() async {
        let vm = HomeViewModel()
        // userLocation is nil, so search should return early without crashing.
        await vm.searchNearbyPlaces(for: .bars)
        #expect(vm.nearbyPlaces.isEmpty)
    }

    @Test func searchNearbyPlacesDoesNothingForAllCategoriesWithoutLocation() async {
        let vm = HomeViewModel()
        for category in PlaceCategory.allCases {
            await vm.searchNearbyPlaces(for: category)
            // Should not crash and places should remain empty.
        }
        #expect(vm.nearbyPlaces.isEmpty)
    }
}
