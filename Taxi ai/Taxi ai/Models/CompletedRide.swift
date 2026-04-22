import Foundation
import SwiftData

/// A record of a completed ride for display in ride history, persisted via SwiftData.
@Model
final class CompletedRide: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var pickupName: String = ""
    var destinationName: String = ""
    var price: Double = 0
    var currencyCode: String = "USD"

    /// PNG snapshot of the map showing the completed route.
    @Attribute(.externalStorage)
    var mapSnapshotData: Data?

    // Rating data (nil if the rider did not submit a rating)
    var starRating: Int?
    var feedbackText: String?
    var tipPercentage: Int?
    var tipAmount: Double?

    /// One-sentence summary generated on-device after the ride is saved.
    /// Nil when Apple Intelligence is unavailable or the generation has not finished.
    var aiSummary: String?

    /// Total price including tip, if any.
    var totalPrice: Double {
        price + (tipAmount ?? 0)
    }

    init(
        date: Date,
        pickupName: String,
        destinationName: String,
        price: Double,
        currencyCode: String,
        mapSnapshotData: Data? = nil,
        starRating: Int? = nil,
        feedbackText: String? = nil,
        tipPercentage: Int? = nil,
        tipAmount: Double? = nil,
        aiSummary: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.pickupName = pickupName
        self.destinationName = destinationName
        self.price = price
        self.currencyCode = currencyCode
        self.mapSnapshotData = mapSnapshotData
        self.starRating = starRating
        self.feedbackText = feedbackText
        self.tipPercentage = tipPercentage
        self.tipAmount = tipAmount
        self.aiSummary = aiSummary
    }
}
