import SwiftData
import SwiftUI

/// List of completed rides showing date, pickup, destination, and price.
struct RideHistoryView: View {
    @Query(sort: \CompletedRide.date, order: .reverse)
    private var rides: [CompletedRide]

    var onDone: () -> Void

    @State private var selectedRide: CompletedRide?

    var body: some View {
        VStack(spacing: 0) {
            RideHistoryHeader(onDone: onDone)

            if rides.isEmpty {
                RideHistoryEmptyState()
            } else {
                RideHistoryList(rides: rides, onSelectRide: { selectedRide = $0 })
            }
        }
        .background(.gray.opacity(0.06))
        .ignoresSafeArea(edges: .top)
        .sheet(item: $selectedRide) { ride in
            CompletedRideDetailView(ride: ride) {
                selectedRide = nil
            }
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Header

/// Top bar with title and close button.
private struct RideHistoryHeader: View {
    var onDone: () -> Void

    var body: some View {
        HStack {
            Text("Ride History")
                .font(.title2.bold())

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 62)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(.background)
    }
}

// MARK: - Empty State

/// Shown when there are no completed rides yet.
private struct RideHistoryEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "car")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No rides yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Your completed rides will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Ride List

/// Scrollable list of completed ride rows.
private struct RideHistoryList: View {
    var rides: [CompletedRide]
    var onSelectRide: (CompletedRide) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rides) { ride in
                    Button {
                        onSelectRide(ride)
                    } label: {
                        RideHistoryRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Ride Row

/// A single ride entry showing date, pickup, destination, and price.
private struct RideHistoryRow: View {
    var ride: CompletedRide

    /// Amber gold color for star ratings.
    private static let starColor = Color(red: 0.961, green: 0.620, blue: 0.043)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date
            Text(ride.date, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            // Star rating (shown only if the rider submitted a rating)
            if let stars = ride.starRating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= stars ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(index <= stars ? Self.starColor : .gray.opacity(0.3))
                    }
                }
            }

            // Route
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    // Pickup
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)

                        Text(ride.pickupName)
                            .font(.subheadline)
                            .lineLimit(1)
                    }

                    // Destination
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.primary)

                        Text(ride.destinationName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Price
                Text(ride.price, format: .currency(code: ride.currencyCode))
                    .font(.headline)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 12))
    }
}
