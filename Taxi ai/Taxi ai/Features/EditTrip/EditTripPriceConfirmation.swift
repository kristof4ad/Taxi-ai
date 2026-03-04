import SwiftUI

/// Overlay showing the price for the new destination, with confirm and cancel buttons.
struct EditTripPriceConfirmation: View {
    var destinationName: String
    var destinationAddress: String
    var newPrice: Double?
    var priceDifference: Double?
    var currencyCode: String
    var isCalculating: Bool
    var onConfirm: () -> Void
    var onCancel: () -> Void

    private static let goldStart = Color(red: 0.831, green: 0.659, blue: 0.294)
    private static let goldEnd = Color(red: 0.722, green: 0.581, blue: 0.290)

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Confirmation card
            VStack(spacing: 16) {
                Text("New Destination")
                    .font(.headline)

                VStack(spacing: 4) {
                    Text(destinationName)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)

                    if !destinationAddress.isEmpty {
                        Text(destinationAddress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Divider()

                if isCalculating {
                    ProgressView("Calculating route...")
                        .padding(.vertical)
                } else if let newPrice {
                    PriceDisplay(
                        newPrice: newPrice,
                        priceDifference: priceDifference,
                        currencyCode: currencyCode
                    )
                }

                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Confirm New Destination")
                            .bold()
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Self.goldStart, Self.goldEnd],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(.rect(cornerRadius: 26))
                            .contentShape(.rect(cornerRadius: 26))
                    }
                    .buttonStyle(.plain)
                    .disabled(newPrice == nil || isCalculating)

                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(.background)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(radius: 20)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Price Display

/// Shows the new total price and the difference from the original price.
private struct PriceDisplay: View {
    var newPrice: Double
    var priceDifference: Double?
    var currencyCode: String

    var body: some View {
        VStack(spacing: 8) {
            Text("New trip price")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(newPrice, format: .currency(code: currencyCode))
                .font(.title.bold())

            if let difference = priceDifference {
                PriceDifferenceBadge(
                    difference: difference,
                    currencyCode: currencyCode
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Price Difference Badge

/// A small badge showing how much extra (or less) the new destination costs.
private struct PriceDifferenceBadge: View {
    var difference: Double
    var currencyCode: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difference >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)

            if difference >= 0 {
                Text("+\(difference, format: .currency(code: currencyCode)) extra")
                    .font(.subheadline.weight(.medium))
            } else {
                Text("\(difference, format: .currency(code: currencyCode)) less")
                    .font(.subheadline.weight(.medium))
            }
        }
        .foregroundStyle(difference >= 0 ? .orange : .green)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            (difference >= 0 ? Color.orange : Color.green).opacity(0.1)
        )
        .clipShape(.rect(cornerRadius: 8))
    }
}
