import SwiftUI

/// Screen prompting the user to close all doors and trunk after exiting.
/// Shows a top-down car image with doors open.
struct CloseDoorsView: View {
    var viewModel: TripViewModel
    var onRateRide: () -> Void
    var onFinishRide: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                CloseDoorsTopRow(
                    onRateRide: onRateRide,
                    isMenuPresented: $isMenuPresented
                )

                CloseDoorsTitle()

                CarTopViewImage()

                CloseDoorsBottomSection(
                    viewModel: viewModel,
                    onFinishRide: onFinishRide
                )
            }
            .background(.gray.opacity(0.1))
            .ignoresSafeArea(edges: .top)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .none,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
    }
}

// MARK: - Top Row

/// "Rate Your Ride" chip button and menu button.
private struct CloseDoorsTopRow: View {
    var onRateRide: () -> Void
    @Binding var isMenuPresented: Bool

    var body: some View {
        HStack {
            Button(action: onRateRide) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt")
                        .font(.caption)

                    Text("Rate Your Ride")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .contentShape(.capsule)
                .background(.background, in: .capsule)
            }
            .buttonStyle(.plain)

            Spacer()

            AppMenuButton(isPresented: $isMenuPresented)
        }
        .padding(.top, 62)
        .padding(.horizontal, 16)
    }
}

// MARK: - Title

/// Bold title asking user to close doors and trunk.
private struct CloseDoorsTitle: View {
    var body: some View {
        Text("Please close all doors and trunk when finished")
            .font(.title2.bold())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.horizontal, 20)
    }
}

// MARK: - Car Top View

/// Top-down image of the car with doors open.
private struct CarTopViewImage: View {
    var body: some View {
        Image("CarTopView")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Bottom Section

/// Walking directions, trunk toggle, and Finish Ride buttons.
private struct CloseDoorsBottomSection: View {
    var viewModel: TripViewModel
    var onFinishRide: () -> Void

    @State private var soundPlayer = SoundPlayer()
    @State private var showWalkingDirections = false

    var body: some View {
        VStack(spacing: 12) {
            // Walking directions button
            Button {
                showWalkingDirections = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.body)

                    Text("Walking Directions to \(viewModel.destinationName ?? "Destination")")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(.capsule)
                .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Trunk toggle button
            Button {
                soundPlayer.playTrunk()
                viewModel.isTrunkOpen.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(viewModel.isTrunkOpen ? "OpenTrunk" : "ClosedTrunk")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(.rect(cornerRadius: 4))

                    Text(viewModel.isTrunkOpen ? "Close Trunk" : "Open Trunk")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(.rect(cornerRadius: 16))
                .background(.background, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Finish Ride button
            GoldButton(title: "Finish Ride", action: onFinishRide)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .sheet(isPresented: $showWalkingDirections) {
            WalkingDirectionsView(
                viewModel: viewModel,
                onDismiss: { showWalkingDirections = false }
            )
        }
    }
}
