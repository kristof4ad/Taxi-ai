import Testing

@testable import Taxi_ai

@MainActor
struct RateRideViewModelTests {
    // MARK: - Tip Calculation

    @Test func tipAmountAtTenPercent() {
        let vm = RateRideViewModel(ridePrice: 20.0, currencyCode: "USD")
        let tip = vm.tipAmount(for: 10)
        #expect(abs(tip - 2.0) < 0.001)
    }

    @Test func tipAmountAtTwentyPercent() {
        let vm = RateRideViewModel(ridePrice: 20.0, currencyCode: "USD")
        let tip = vm.tipAmount(for: 20)
        #expect(abs(tip - 4.0) < 0.001)
    }

    @Test func tipAmountAtThirtyPercent() {
        let vm = RateRideViewModel(ridePrice: 20.0, currencyCode: "USD")
        let tip = vm.tipAmount(for: 30)
        #expect(abs(tip - 6.0) < 0.001)
    }

    @Test func tipAmountWithZeroPrice() {
        let vm = RateRideViewModel(ridePrice: 0, currencyCode: "USD")
        let tip = vm.tipAmount(for: 20)
        #expect(tip == 0)
    }

    @Test func tipAmountWithLargePrice() {
        let vm = RateRideViewModel(ridePrice: 150.0, currencyCode: "EUR")
        let tip = vm.tipAmount(for: 10)
        #expect(abs(tip - 15.0) < 0.001)
    }

    // MARK: - Form Validation

    @Test func cannotSubmitWithZeroStars() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        #expect(vm.canSubmit == false)
    }

    @Test func canSubmitWithOneStar() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        vm.starRating = 1
        #expect(vm.canSubmit == true)
    }

    @Test func canSubmitWithFiveStars() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        vm.starRating = 5
        #expect(vm.canSubmit == true)
    }

    // MARK: - Build Rating

    @Test func buildRatingCapturesStarRating() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        vm.starRating = 4

        let rating = vm.buildRating()
        #expect(rating.starRating == 4)
    }

    @Test func buildRatingCapturesFeedbackText() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        vm.starRating = 3
        vm.feedbackText = "Great ride!"

        let rating = vm.buildRating()
        #expect(rating.feedbackText == "Great ride!")
    }

    @Test func buildRatingWithNoTipHasNilTipFields() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        vm.starRating = 5

        let rating = vm.buildRating()
        #expect(rating.tipPercentage == nil)
        #expect(rating.tipAmount == nil)
    }

    @Test func buildRatingWithTipCalculatesAmount() {
        let vm = RateRideViewModel(ridePrice: 20.0, currencyCode: "USD")
        vm.starRating = 5
        vm.selectedTipPercentage = 20

        let rating = vm.buildRating()
        #expect(rating.tipPercentage == 20)
        #expect(rating.tipAmount != nil)
        #expect(abs(rating.tipAmount! - 4.0) < 0.001)
    }

    @Test func buildRatingWithEmptyFeedback() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")
        vm.starRating = 3

        let rating = vm.buildRating()
        #expect(rating.feedbackText.isEmpty)
    }

    // MARK: - Prepopulation from Existing Rating

    @Test func initWithExistingRatingPrepopulatesStars() {
        let existing = RideRating(
            starRating: 4,
            feedbackText: "Smooth ride",
            tipPercentage: 20,
            tipAmount: 3.0
        )
        let vm = RateRideViewModel(ridePrice: 15.0, currencyCode: "USD", existingRating: existing)

        #expect(vm.starRating == 4)
    }

    @Test func initWithExistingRatingPrepopulatesFeedback() {
        let existing = RideRating(
            starRating: 4,
            feedbackText: "Smooth ride",
            tipPercentage: 20,
            tipAmount: 3.0
        )
        let vm = RateRideViewModel(ridePrice: 15.0, currencyCode: "USD", existingRating: existing)

        #expect(vm.feedbackText == "Smooth ride")
    }

    @Test func initWithExistingRatingPrepopulatesTip() {
        let existing = RideRating(
            starRating: 4,
            feedbackText: "",
            tipPercentage: 30,
            tipAmount: 4.5
        )
        let vm = RateRideViewModel(ridePrice: 15.0, currencyCode: "USD", existingRating: existing)

        #expect(vm.selectedTipPercentage == 30)
    }

    @Test func initWithoutExistingRatingHasDefaults() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "USD")

        #expect(vm.starRating == 0)
        #expect(vm.feedbackText.isEmpty)
        #expect(vm.selectedTipPercentage == nil)
    }

    // MARK: - Currency Code

    @Test func currencyCodeIsStored() {
        let vm = RateRideViewModel(ridePrice: 10.0, currencyCode: "EUR")
        #expect(vm.currencyCode == "EUR")
    }

    @Test func ridePriceIsStored() {
        let vm = RateRideViewModel(ridePrice: 42.50, currencyCode: "GBP")
        #expect(vm.ridePrice == 42.50)
    }

    // MARK: - Tip Percentages Constant

    @Test func availableTipPercentages() {
        #expect(RateRideViewModel.tipPercentages == [10, 20, 30])
    }
}
