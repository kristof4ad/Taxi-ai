import SwiftUI

/// Screen prompting the user to close all doors and trunk after exiting.
/// Shows a top-down car image with doors open.
struct CloseDoorsView: View {
    var viewModel: TripViewModel
    var onFinishRide: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                CloseDoorsTopRow(isMenuPresented: $isMenuPresented)

                CloseDoorsTitle()

                CarTopViewImage()

                CloseDoorsBottomSection(
                    destinationName: viewModel.destinationName,
                    onFinishRide: onFinishRide
                )
            }
            .background(.gray.opacity(0.1))

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

/// "Rate Your Ride" chip and menu button.
private struct CloseDoorsTopRow: View {
    @Binding var isMenuPresented: Bool

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "bolt")
                    .font(.caption)

                Text("Rate Your Ride")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(.background, in: .capsule)

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
        Text("Please close all doors and trunk\nwhen finished")
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

/// Walking directions, Open Trunk, and Finish Ride buttons.
private struct CloseDoorsBottomSection: View {
    var destinationName: String?
    var onFinishRide: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Walking directions button
            Button {
                // Walking directions placeholder
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.body)

                    Text("Walking Directions to \(destinationName ?? "Destination")")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.primary, in: .capsule)
            }
            .buttonStyle(.plain)

            // Open Trunk button
            Button {
                // Open trunk placeholder
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.body)

                    Text("Open Trunk")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.background, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Finish Ride button
            Button("Finish Ride", action: onFinishRide)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}
