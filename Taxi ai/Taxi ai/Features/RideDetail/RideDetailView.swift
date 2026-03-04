import MapKit
import SwiftUI

/// Summary screen shown after a ride is complete with route, payment, and trip details.
struct RideDetailView: View {
    var viewModel: TripViewModel
    var onFinished: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RideDetailTopRow()

                RideDetailMap(viewModel: viewModel)

                RideDetailStats(viewModel: viewModel)

                RideDetailLabels()

                RideDetailRouteCard(viewModel: viewModel)

                RideDetailPayment(viewModel: viewModel)

                Divider()
                    .padding(.horizontal, 16)

                RideDetailLostItem()

                RideDetailFinishedButton(onFinished: onFinished)
            }
        }
        .scrollIndicators(.hidden)
        .background(.background)
    }
}

// MARK: - Top Row

/// Ride date header.
private struct RideDetailTopRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Text(Date.now, format: .dateTime.month(.wide).day().year().hour().minute())
                .font(.subheadline.weight(.medium))

            Spacer()
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

                Text("Pickup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pickup")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(Date.now, format: .dateTime.hour().minute())
                        .font(.subheadline.weight(.medium))
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

                Text("Dropoff")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Finished Button

/// Full-width button to complete the ride review and proceed to history.
private struct RideDetailFinishedButton: View {
    var onFinished: () -> Void

    var body: some View {
        Button("Finished", action: onFinished)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.primary, in: .capsule)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
    }
}
