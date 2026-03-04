import Foundation

/// View model for the rate-your-ride sheet, managing star selection, feedback text, and tip choice.
@MainActor
@Observable
final class RateRideViewModel {
    /// Selected star rating (0 means no selection yet).
    var starRating: Int = 0
    /// Written feedback from the rider.
    var feedbackText: String = ""
    /// Currently selected tip percentage, or nil if none.
    var selectedTipPercentage: Int?

    /// The ride price used to calculate tip amounts.
    let ridePrice: Double
    /// The currency code for displaying tip amounts.
    let currencyCode: String

    /// Available tip percentage options.
    static let tipPercentages = [10, 20, 30]

    init(ridePrice: Double, currencyCode: String, existingRating: RideRating? = nil) {
        self.ridePrice = ridePrice
        self.currencyCode = currencyCode

        if let existingRating {
            self.starRating = existingRating.starRating
            self.feedbackText = existingRating.feedbackText
            self.selectedTipPercentage = existingRating.tipPercentage
        }
    }

    /// Calculates the tip amount for a given percentage.
    func tipAmount(for percentage: Int) -> Double {
        ridePrice * Double(percentage) / 100
    }

    /// Whether the form can be submitted (at least one star selected).
    var canSubmit: Bool {
        starRating >= 1
    }

    /// Builds the final rating from the current form state.
    func buildRating() -> RideRating {
        RideRating(
            starRating: starRating,
            feedbackText: feedbackText,
            tipPercentage: selectedTipPercentage,
            tipAmount: selectedTipPercentage.map { tipAmount(for: $0) }
        )
    }
}
