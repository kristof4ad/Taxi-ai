import FoundationModels
import Foundation
import OSLog

private let log = Logger(subsystem: "com.ikristof.Taxi-ai", category: "Intelligence")

/// On-device AI helper backed by Apple's Foundation Models framework.
///
/// All methods return `nil` when the system model is unavailable (device
/// ineligible, Apple Intelligence off, or the model is still downloading) so
/// callers can degrade silently without surfacing any error UI.
@MainActor
@Observable
final class IntelligenceService {
    /// Whether the on-device model is ready to serve requests.
    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    // MARK: - Feature A — Natural-language search interpretation

    /// Interprets a free-form destination search (e.g. "somewhere quiet to read")
    /// and returns a MapKit-friendly query plus a short chip label.
    func interpretSearch(_ query: String) async -> SearchInterpretation? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let availability = SystemLanguageModel.default.availability
        log.info("interpret: query=\(trimmed, privacy: .public) available=\(String(describing: availability), privacy: .public)")

        guard isAvailable else {
            log.info("interpret: skipped — Apple Intelligence unavailable")
            return nil
        }
        guard trimmed.count >= 3 else { return nil }

        let session = LanguageModelSession {
            Self.searchInstructions
        }

        do {
            let response = try await session.respond(
                to: Self.searchPrompt(for: trimmed),
                generating: SearchInterpretation.self
            )
            let interpretation = response.content
            log.info("interpret: model said shouldSuggest=\(interpretation.shouldSuggest)")
            log.info("interpret: rewrite=\(interpretation.rewrittenQuery, privacy: .public)")
            log.info("interpret: label=\(interpretation.label, privacy: .public)")

            guard interpretation.shouldSuggest else { return nil }
            let rewrite = interpretation.rewrittenQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rewrite.isEmpty, rewrite.localizedCaseInsensitiveCompare(trimmed) != .orderedSame else {
                log.info("interpret: dropping suggestion — empty or same as input")
                return nil
            }
            return interpretation
        } catch {
            log.error("interpret: model failed \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Feature D — Per-ride summary

    /// Generates a one-sentence friendly summary for a completed ride.
    func summarizeRide(
        pickup: String,
        destination: String,
        priceDisplay: String,
        starRating: Int?,
        feedback: String?
    ) async -> String? {
        guard isAvailable else { return nil }

        let session = LanguageModelSession {
            Self.summaryInstructions
        }

        do {
            let response = try await session.respond(
                to: Self.summaryPrompt(
                    pickup: pickup,
                    destination: destination,
                    priceDisplay: priceDisplay,
                    starRating: starRating,
                    feedback: feedback
                )
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // MARK: - Feature D — Weekly recap

    /// Generates a 1-2 sentence recap of the rides taken in the given window.
    func weeklyRecap(from rides: [RecapRideInput]) async -> RideRecap? {
        guard isAvailable, !rides.isEmpty else { return nil }

        let session = LanguageModelSession {
            Self.recapInstructions
        }

        do {
            let response = try await session.respond(
                to: Self.recapPrompt(for: rides),
                generating: RideRecap.self
            )
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Prompt construction (pure, testable)

    static let searchInstructions = """
    You help interpret short taxi destination searches on iOS. The user's text may be a literal place \
    ("Starbucks"), a mood ("quiet coffee"), or a need ("groceries on the way home").

    When the input is a mood or need:
    - shouldSuggest: true
    - rewrittenQuery: a concrete MapKit search term, one to three lowercase words (for example \
      "coffee", "bookstore", "grocery store")
    - label: a short human-readable phrase (three to six words) that KEEPS the user's descriptive \
      words ("quiet", "cheap", "late-night", etc.) so they recognise their own intent. Do NOT collapse \
      the label into just the MapKit term.

    Examples:
    - "quiet coffee" → rewrittenQuery "coffee", label "Quiet coffee spots"
    - "somewhere cheap to eat" → rewrittenQuery "restaurant", label "Cheap eats nearby"
    - "late-night food" → rewrittenQuery "restaurant", label "Late-night food"

    Conversational needs count as moods too. Treat "I want to X", "I'm X", "I need X", or similar \
    phrasing as a need — always set shouldSuggest true and map to the closest concrete place.

    - "I want to watch a movie" → rewrittenQuery "cinema", label "Movie theaters nearby"
    - "I'm hungry" → rewrittenQuery "restaurant", label "Food nearby"
    - "I need groceries" → rewrittenQuery "grocery store", label "Groceries nearby"
    - "I want a coffee" → rewrittenQuery "coffee", label "Coffee nearby"
    - "take me somewhere to dance" → rewrittenQuery "nightclub", label "Dance spots nearby"

    When the input is already a specific place or brand name, set shouldSuggest to false and leave \
    the other fields empty strings.
    """

    static let summaryInstructions = """
    You write single-sentence ride summaries for a taxi app's ride history. \
    Be friendly, concise, and factual. Never use emojis, markdown, or quotation marks. Return only the sentence itself.
    """

    static let recapInstructions = """
    You write short weekly recaps for a taxi app's ride history screen. Keep headlines \
    three to six words and bodies under thirty words total. Never use emojis, markdown, or bullet lists.
    """

    static func searchPrompt(for query: String) -> String {
        "User typed: \"\(query)\""
    }

    static func summaryPrompt(
        pickup: String,
        destination: String,
        priceDisplay: String,
        starRating: Int?,
        feedback: String?
    ) -> String {
        var lines = [
            "Pickup: \(pickup)",
            "Destination: \(destination)",
            "Fare: \(priceDisplay)"
        ]
        if let starRating {
            lines.append("Rating: \(starRating) of 5 stars")
        }
        if let feedback, !feedback.isEmpty {
            lines.append("Rider feedback: \(feedback)")
        }
        lines.append("")
        lines.append("Write one friendly sentence, maximum 15 words, summarising this ride.")
        return lines.joined(separator: "\n")
    }

    static func recapPrompt(for rides: [RecapRideInput]) -> String {
        let rideLines = rides.map { ride in
            var line = "- \(ride.destination) for \(ride.priceDisplay)"
            if let stars = ride.starRating {
                line += " (\(stars)★)"
            }
            return line
        }.joined(separator: "\n")

        return """
        Rides in the past 7 days:
        \(rideLines)

        Write a short recap with a headline and a 1-2 sentence body.
        """
    }
}
