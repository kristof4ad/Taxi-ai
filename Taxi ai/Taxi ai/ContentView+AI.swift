import SwiftUI

extension ContentView {
    /// Requests a one-sentence summary from the on-device model and writes it
    /// back to the ride. Silently no-ops when the model is unavailable.
    func generateSummary(for ride: CompletedRide) {
        let priceDisplay = ride.totalPrice.formatted(.currency(code: ride.currencyCode))
        let pickup = ride.pickupName
        let destination = ride.destinationName
        let stars = ride.starRating
        let feedback = ride.feedbackText
        let service = intelligenceService
        Task {
            let summary = await service.summarizeRide(
                pickup: pickup,
                destination: destination,
                priceDisplay: priceDisplay,
                starRating: stars,
                feedback: feedback
            )
            guard let summary else { return }
            ride.aiSummary = summary
            save()
        }
    }
}
