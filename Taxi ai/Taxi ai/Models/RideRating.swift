import Foundation

/// Data captured from the post-ride rating screen.
struct RideRating: Sendable {
    /// Star rating from 1 to 5.
    let starRating: Int
    /// Written feedback from the rider (may be empty).
    let feedbackText: String
    /// Selected tip percentage (10, 20, or 30), or nil if no tip.
    let tipPercentage: Int?
    /// Calculated tip amount based on ride price, or nil if no tip.
    let tipAmount: Double?
}
