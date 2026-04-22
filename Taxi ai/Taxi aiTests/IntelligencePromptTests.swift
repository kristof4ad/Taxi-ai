import Testing

@testable import Taxi_ai

@MainActor
struct IntelligencePromptTests {
    // MARK: - Search prompt

    @Test func searchPromptEmbedsTheUserQuery() {
        let prompt = IntelligenceService.searchPrompt(for: "somewhere quiet to read")
        #expect(prompt.contains("somewhere quiet to read"))
    }

    @Test func searchInstructionsMentionShouldSuggestToggle() {
        #expect(IntelligenceService.searchInstructions.contains("shouldSuggest"))
    }

    @Test func searchInstructionsMentionConversationalNeeds() {
        let instructions = IntelligenceService.searchInstructions
        #expect(instructions.contains("I'm hungry"))
        #expect(instructions.contains("I want to watch a movie"))
    }

    // MARK: - Summary prompt

    @Test func summaryPromptIncludesPickupAndDestinationAndFare() {
        let prompt = IntelligenceService.summaryPrompt(
            pickup: "Home",
            destination: "Central Park",
            priceDisplay: "$8.20",
            starRating: nil,
            feedback: nil
        )
        #expect(prompt.contains("Home"))
        #expect(prompt.contains("Central Park"))
        #expect(prompt.contains("$8.20"))
    }

    @Test func summaryPromptIncludesRatingAndFeedbackWhenProvided() {
        let prompt = IntelligenceService.summaryPrompt(
            pickup: "Home",
            destination: "Airport",
            priceDisplay: "$22.00",
            starRating: 5,
            feedback: "Driver was great"
        )
        #expect(prompt.contains("5"))
        #expect(prompt.contains("Driver was great"))
    }

    @Test func summaryPromptOmitsOptionalsWhenNotProvided() {
        let prompt = IntelligenceService.summaryPrompt(
            pickup: "A",
            destination: "B",
            priceDisplay: "$1",
            starRating: nil,
            feedback: nil
        )
        #expect(!prompt.contains("Rating"))
        #expect(!prompt.contains("feedback"))
    }

    @Test func summaryPromptOmitsEmptyFeedback() {
        let prompt = IntelligenceService.summaryPrompt(
            pickup: "A",
            destination: "B",
            priceDisplay: "$1",
            starRating: 4,
            feedback: ""
        )
        #expect(!prompt.contains("feedback"))
    }

    // MARK: - Recap prompt

    @Test func recapPromptListsEveryRide() {
        let rides = [
            RecapRideInput(destination: "Gym", priceDisplay: "$5", starRating: 4),
            RecapRideInput(destination: "Office", priceDisplay: "$8", starRating: nil),
            RecapRideInput(destination: "Park", priceDisplay: "$6", starRating: 5)
        ]
        let prompt = IntelligenceService.recapPrompt(for: rides)
        #expect(prompt.contains("Gym"))
        #expect(prompt.contains("Office"))
        #expect(prompt.contains("Park"))
    }

    @Test func recapPromptIncludesStarsWhenRated() {
        let rides = [
            RecapRideInput(destination: "Park", priceDisplay: "$6", starRating: 5)
        ]
        let prompt = IntelligenceService.recapPrompt(for: rides)
        #expect(prompt.contains("5★"))
    }

    @Test func recapPromptOmitsStarsWhenUnrated() {
        let rides = [
            RecapRideInput(destination: "Park", priceDisplay: "$6", starRating: nil)
        ]
        let prompt = IntelligenceService.recapPrompt(for: rides)
        #expect(!prompt.contains("★"))
    }
}
