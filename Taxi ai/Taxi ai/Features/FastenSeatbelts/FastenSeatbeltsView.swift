import SwiftUI

/// Screen prompting the user to fasten their seatbelt before the ride begins.
/// Shows a seatbelt illustration with action buttons for trip management.
struct FastenSeatbeltsView: View {
    var viewModel: TripViewModel
    var onFastened: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false
    @State private var showEditTrip = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                FastenSeatbeltsHeader(isMenuPresented: $isMenuPresented)

                SeatbeltIllustration()

                FastenSeatbeltsActions(
                    onFastened: onFastened,
                    onEditTrip: { showEditTrip = true }
                )
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

// MARK: - Header

/// Top section with menu button, subtitle, and title.
private struct FastenSeatbeltsHeader: View {
    @Binding var isMenuPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Menu row
            HStack {
                Spacer()
                AppMenuButton(isPresented: $isMenuPresented)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Text section
            VStack(spacing: 4) {
                Text("To continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Fasten Seatbelts")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

// MARK: - Seatbelt Illustration

/// Illustration of a car seat with a fastened seatbelt.
private struct SeatbeltIllustration: View {
    var body: some View {
        Image("SeatbeltIllustration")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
    }
}

// MARK: - Actions

/// Edit/Lock row and gold "Fastened" button.
private struct FastenSeatbeltsActions: View {
    var onFastened: () -> Void
    var onEditTrip: () -> Void

    @State private var isLocked = true
    @State private var soundPlayer = SoundPlayer()

    private static let goldStart = Color(red: 0.831, green: 0.659, blue: 0.294)
    private static let goldEnd = Color(red: 0.722, green: 0.581, blue: 0.290)

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionGridButton(title: "Edit Trip", icon: "pencil", action: onEditTrip)
                ActionGridButton(
                    title: isLocked ? "Lock" : "Unlock",
                    icon: isLocked ? "lock" : "lock.open",
                    action: {
                        soundPlayer.playLock()
                        isLocked.toggle()
                    }
                )
            }

            Button(action: onFastened) {
                Text("Fastened")
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
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Action Grid Button

private struct ActionGridButton: View {
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
            .frame(height: 56)
            .contentShape(.rect(cornerRadius: 16))
            .background(.fill, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
