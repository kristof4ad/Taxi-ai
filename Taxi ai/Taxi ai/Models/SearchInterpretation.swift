import FoundationModels

/// Structured output produced by the on-device language model when interpreting
/// a natural-language destination search (e.g. "somewhere quiet to read").
@Generable
struct SearchInterpretation: Sendable, Equatable {
    @Guide(description: "True when the text is a mood or need we should rewrite. False when it's a specific place or brand.")
    let shouldSuggest: Bool

    @Guide(description: "A concrete MapKit term, 1-3 lowercase words. Empty when shouldSuggest is false.")
    let rewrittenQuery: String

    @Guide(description: "Chip title, 3-6 words. Keep adjectives like 'quiet', 'cheap'. Empty if shouldSuggest is false.")
    let label: String
}
