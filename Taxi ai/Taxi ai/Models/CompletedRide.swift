import Foundation

/// A record of a completed ride for display in ride history.
struct CompletedRide: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let pickupName: String
    let destinationName: String
    let price: Double
    let currencyCode: String
}
