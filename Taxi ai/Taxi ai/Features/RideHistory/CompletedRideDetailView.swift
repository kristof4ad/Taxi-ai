import SwiftUI

/// Detail view for a completed ride shown when tapping a row in ride history.
struct CompletedRideDetailView: View {
    var ride: CompletedRide
    var onDismiss: () -> Void

    private var tripFare: Double {
        ride.price * 0.97
    }

    private var tax: Double {
        ride.price * 0.03
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CompletedRideDetailHeader(ride: ride, onDismiss: onDismiss)

                CompletedRideDetailPrice(ride: ride)

                CompletedRideDetailRouteCard(ride: ride)

                CompletedRideDetailPayment(
                    tripFare: tripFare,
                    tax: tax,
                    currencyCode: ride.currencyCode
                )

                if let stars = ride.starRating {
                    Divider()
                        .padding(.horizontal, 16)

                    CompletedRideDetailRating(ride: ride, stars: stars)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(.background)
    }
}

// MARK: - Header

/// Date and close button.
private struct CompletedRideDetailHeader: View {
    var ride: CompletedRide
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(ride.date, format: .dateTime.month(.wide).day().year().hour().minute())
                .font(.subheadline.weight(.medium))

            Spacer()

            Button("Close", systemImage: "xmark.circle.fill", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Price

/// Large total price display.
private struct CompletedRideDetailPrice: View {
    var ride: CompletedRide

    var body: some View {
        HStack {
            Spacer()

            Text(ride.price, format: .currency(code: ride.currencyCode))
                .font(.title3.bold())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Route Card

/// Pickup and destination with connecting line.
private struct CompletedRideDetailRouteCard: View {
    var ride: CompletedRide

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(ride.pickupName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2, height: 20)
                    .padding(.leading, 5)

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(ride.destinationName)
                    .font(.subheadline.weight(.medium))

                Spacer()
            }
        }
        .padding(16)
        .background(.gray.opacity(0.08), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Payment

/// Fare and tax breakdown.
private struct CompletedRideDetailPayment: View {
    var tripFare: Double
    var tax: Double
    var currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment")
                .font(.headline)
                .padding(.bottom, 4)

            HStack {
                Text("Trip Fare")
                    .font(.subheadline)

                Spacer()

                Text(tripFare, format: .currency(code: currencyCode))
                    .font(.subheadline)
            }

            HStack {
                Text("Congestion Charge")
                    .font(.subheadline)

                Spacer()

                Text(tax, format: .currency(code: currencyCode))
                    .font(.subheadline)
            }

            Text("VISA · ****")
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Rating

/// Star rating, feedback, and tip.
private struct CompletedRideDetailRating: View {
    var ride: CompletedRide
    var stars: Int

    /// Amber gold color for star ratings.
    private static let starColor = Color(red: 0.961, green: 0.620, blue: 0.043)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Rating")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= stars ? "star.fill" : "star")
                        .foregroundStyle(
                            index <= stars ? Self.starColor : .gray.opacity(0.3)
                        )
                }
            }

            if let feedback = ride.feedbackText, !feedback.isEmpty {
                Text(feedback)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.gray.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            if let tipAmount = ride.tipAmount, let tipPct = ride.tipPercentage {
                HStack {
                    Text("Tip (\(tipPct)%)")
                        .font(.subheadline)

                    Spacer()

                    Text(tipAmount, format: .currency(code: ride.currencyCode))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
