import MapKit
import SwiftUI

/// Summary screen shown after a ride is complete with route, payment, and trip details.
struct RideDetailView: View {
    var viewModel: TripViewModel
    var rating: RideRating?
    var onFinished: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    RideDetailTopRow(isMenuPresented: $isMenuPresented)

                    RideDetailMap(viewModel: viewModel)

                    RideDetailStats(viewModel: viewModel)

                    RideDetailLabels()

                    RideDetailRouteCard(viewModel: viewModel)

                    RideDetailPayment(viewModel: viewModel)

                    if let rating {
                        Divider()
                            .padding(.horizontal, 16)

                        RideDetailRatingSection(
                            rating: rating,
                            currencyCode: viewModel.displayCurrencyCode
                        )
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    RideDetailLostItem()

                    RideDetailFinishedButton(onFinished: onFinished)
                }
            }
            .scrollIndicators(.hidden)
            .background(.background)
            .ignoresSafeArea(edges: .top)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .riding,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
    }
}

// MARK: - Top Row

/// Ride date header with menu button.
private struct RideDetailTopRow: View {
    @Binding var isMenuPresented: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(Date.now, format: .dateTime.month(.wide).day().year().hour().minute())
                .font(.subheadline.weight(.medium))

            Spacer()

            AppMenuButton(isPresented: $isMenuPresented)
        }
        .padding(.top, 62)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Map

/// Static map showing the completed route.
private struct RideDetailMap: View {
    var viewModel: TripViewModel

    var body: some View {
        Map {
            if let destination = viewModel.destination {
                Annotation("Destination", coordinate: destination) {
                    DestinationMarkerView()
                }
            }

            if let route = viewModel.route {
                MapPolyline(route)
                    .stroke(.blue, lineWidth: 4)
            }
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .frame(height: 260)
    }
}

// MARK: - Stats Row

/// Distance/duration and total price.
private struct RideDetailStats: View {
    var viewModel: TripViewModel

    var body: some View {
        HStack {
            if let tripInfo = viewModel.tripInfo {
                let distance = Measurement(
                    value: tripInfo.distance,
                    unit: UnitLength.meters
                )
                Text(
                    distance.formatted(.measurement(width: .abbreviated, usage: .road))
                    + " · "
                    + Duration.seconds(tripInfo.expectedTravelTime)
                        .formatted(.units(allowed: [.minutes], zeroValueUnits: .show(length: 1)))
                )
                .font(.subheadline.weight(.semibold))
            }

            Spacer()

            if let price = viewModel.estimatedPrice {
                Text(price, format: .currency(code: viewModel.displayCurrencyCode))
                    .font(.title3.bold())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Labels Row

/// "License Plate" and "Total" labels beneath the stats.
private struct RideDetailLabels: View {
    var body: some View {
        HStack {
            Text("License Plate:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Route Card

/// Card showing pickup and drop-off locations with a connecting line.
private struct RideDetailRouteCard: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Pickup row
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(viewModel.pickupAddress ?? "Pickup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pickup")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let startDate = viewModel.rideStartDate {
                        Text(startDate, format: .dateTime.hour().minute())
                            .font(.subheadline.weight(.medium))
                    }
                }
            }

            // Connector
            HStack {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2, height: 20)
                    .padding(.leading, 5)

                Spacer()
            }

            // Dropoff row
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(viewModel.destinationAddress ?? viewModel.destinationName ?? "Destination")
                    .font(.subheadline.weight(.medium))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Dropoff")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let startDate = viewModel.rideStartDate,
                       let travelTime = viewModel.tripInfo?.expectedTravelTime {
                        Text(
                            startDate.addingTimeInterval(travelTime),
                            format: .dateTime.hour().minute()
                        )
                        .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        .padding(16)
        .background(.gray.opacity(0.08), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Payment Section

/// Payment breakdown with fare, taxes, and card info.
private struct RideDetailPayment: View {
    var viewModel: TripViewModel

    private var tripFare: Double {
        guard let price = viewModel.estimatedPrice else { return 0 }
        return price * 0.97 // Fare before tax
    }

    private var tax: Double {
        guard let price = viewModel.estimatedPrice else { return 0 }
        return price * 0.03 // ~3% tax
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment")
                .font(.headline)
                .padding(.bottom, 4)

            // Trip Fare
            HStack {
                Text("Trip Fare")
                    .font(.subheadline)

                Spacer()

                Text(tripFare, format: .currency(code: viewModel.displayCurrencyCode))
                    .font(.subheadline)
            }

            // Tax
            HStack {
                Text("SF Traffic Congestion Mitigation Tax")
                    .font(.subheadline)

                Spacer()

                Text(tax, format: .currency(code: viewModel.displayCurrencyCode))
                    .font(.subheadline)
            }

            // Card
            Text("AMEX · ****")
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Lost Item

/// Link to report a lost item with a deadline.
private struct RideDetailLostItem: View {
    private var deadline: String {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return futureDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        HStack {
            Text("Report a Lost Item by \(deadline)")
                .font(.subheadline.weight(.semibold))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Rating Section

/// Shows the rider's submitted rating, feedback, and tip.
private struct RideDetailRatingSection: View {
    var rating: RideRating
    var currencyCode: String

    /// Amber gold color for star ratings.
    private static let starColor = Color(red: 0.961, green: 0.620, blue: 0.043)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Rating")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating.starRating ? "star.fill" : "star")
                        .foregroundStyle(
                            index <= rating.starRating ? Self.starColor : .gray.opacity(0.3)
                        )
                }
            }

            if !rating.feedbackText.isEmpty {
                Text(rating.feedbackText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.gray.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            if let tipAmount = rating.tipAmount, let tipPct = rating.tipPercentage {
                HStack {
                    Text("Tip (\(tipPct)%)")
                        .font(.subheadline)

                    Spacer()

                    Text(tipAmount, format: .currency(code: currencyCode))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Finished Button

/// Full-width button to complete the ride review and proceed to history.
private struct RideDetailFinishedButton: View {
    var onFinished: () -> Void

    var body: some View {
        Button(action: onFinished) {
            Text("Finished")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(.capsule)
                .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
    }
}
