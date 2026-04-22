/// Sendable value type for passing ride info into `IntelligenceService.weeklyRecap`.
struct RecapRideInput: Sendable, Equatable {
    let destination: String
    let priceDisplay: String
    let starRating: Int?
}
