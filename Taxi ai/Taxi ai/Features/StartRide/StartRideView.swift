import SwiftUI

/// Screen shown after seatbelts are fastened, allowing the user to start the ride.
/// Displays the destination name and a large circular "START RIDE" button.
struct StartRideView: View {
    var viewModel: TripViewModel
    var onStartRide: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false
    @State private var showEditTrip = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                StartRideTopBar(isMenuPresented: $isMenuPresented)

                StartRideHeading(destinationName: viewModel.destinationName)

                StartRideCircle(onStartRide: onStartRide)

                StartRideActionButtons(onEditTrip: { showEditTrip = true })
            }
            .background(.background)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .ordering,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
        .sheet(isPresented: $showEditTrip) {
            if let origin = viewModel.currentRouteOrigin {
                EditTripView(
                    tripViewModel: viewModel,
                    viewModel: EditTripViewModel(
                        locationService: viewModel.locationService,
                        currencyService: viewModel.currencyService,
                        originalPrice: viewModel.estimatedPrice,
                        routeOrigin: origin
                    ),
                    onConfirm: { showEditTrip = false },
                    onDismiss: { showEditTrip = false }
                )
            }
        }
    }
}

// MARK: - Top Bar

private struct StartRideTopBar: View {
    @Binding var isMenuPresented: Bool

    var body: some View {
        HStack {
            Spacer()

            AppMenuButton(isPresented: $isMenuPresented)
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
    var onEditTrip: () -> Void

    @State private var isLocked = true
    @State private var soundPlayer = SoundPlayer()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StartRideActionButton(title: "Edit Trip", icon: "pencil", action: onEditTrip)
                StartRideActionButton(
                    title: isLocked ? "Lock" : "Unlock",
                    icon: isLocked ? "lock" : "lock.open",
                    action: {
                        soundPlayer.playLock()
                        isLocked.toggle()
                    }
                )
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
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
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
