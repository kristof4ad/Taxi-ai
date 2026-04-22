import FoundationModels

/// Structured output for the weekly ride recap shown at the top of Ride History.
@Generable
struct RideRecap: Sendable, Equatable {
    @Guide(description: "Short headline, 3-6 words, no emojis.")
    let headline: String

    @Guide(description: "1-2 sentences, 30 words max. Cover ride count, top place, total spent. No emojis or bullets.")
    let body: String
}
