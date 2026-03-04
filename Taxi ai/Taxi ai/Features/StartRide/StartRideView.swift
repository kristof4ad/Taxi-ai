import SwiftUI

/// Screen shown after seatbelts are fastened, allowing the user to start the ride.
/// Displays the destination name and a large circular "START RIDE" button.
struct StartRideView: View {
    var viewModel: TripViewModel
    var onStartRide: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StartRideTopBar()

            StartRideHeading(destinationName: viewModel.destinationName)

            StartRideCircle(onStartRide: onStartRide)

            StartRideActionButtons()
        }
        .background(.background)
    }
}

// MARK: - Top Bar

private struct StartRideTopBar: View {
    var body: some View {
        HStack {
            Spacer()

            Button("Menu", systemImage: "line.3.horizontal") {
                // Menu action placeholder
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(.primary)
            .frame(width: 40, height: 40)
            .background(.background, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .padding(.top, 62)
        .padding(.horizontal, 16)
    }
}

// MARK: - Heading

/// Subtitle and destination name displayed in gold.
private struct StartRideHeading: View {
    var destinationName: String?

    private static let goldText = Color(red: 0.831, green: 0.659, blue: 0.294)

    var body: some View {
        VStack(spacing: 4) {
            Text("Heading to")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(destinationName ?? "Destination")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Self.goldText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Start Ride Circle

/// Large circular button with "START RIDE" text to begin the trip.
private struct StartRideCircle: View {
    var onStartRide: () -> Void

    var body: some View {
        Button(action: onStartRide) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 3)
                    .frame(width: 200, height: 200)

                Text("START RIDE")
                    .font(.body.weight(.semibold))
                    .tracking(4)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Action Buttons

/// Edit Trip and Lock buttons row.
private struct StartRideActionButtons: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StartRideActionButton(title: "Edit Trip", icon: "pencil")
                StartRideActionButton(title: "Lock", icon: "lock")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Action Button

private struct StartRideActionButton: View {
    var title: String
    var icon: String?

    var body: some View {
        Button {
            // Action placeholder
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                }

                Text(title)
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
