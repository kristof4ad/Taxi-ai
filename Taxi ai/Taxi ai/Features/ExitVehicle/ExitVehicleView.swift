import SwiftUI

/// Screen shown when the ride is complete, prompting the user to exit the vehicle safely.
struct ExitVehicleView: View {
    var viewModel: TripViewModel
    var onRateRide: () -> Void
    var onOpenDoor: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ExitVehicleTopRow(
                    onRateRide: onRateRide,
                    isMenuPresented: $isMenuPresented
                )

                ExitVehicleTextSection()

                DoorIllustrationView()

                ExitVehicleActionButtons(
                    viewModel: viewModel,
                    onOpenDoor: onOpenDoor
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

/// Top bar with "Rate Your Ride" chip and menu button.
private struct ExitVehicleTopRow: View {
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
                .frame(height: 36)
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

// MARK: - Text Section

/// Subtitle and title prompting safe exit.
private struct ExitVehicleTextSection: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Don't forget your belongings")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Please exit the vehicle safely")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.horizontal, 20)
    }
}

// MARK: - Door Illustration

/// Line-art illustration of a car door with a blue "open" indicator.
private struct DoorIllustrationView: View {
    var body: some View {
        ZStack {
            // Door panel background
            DoorPanelShape()
                .stroke(.gray.opacity(0.3), lineWidth: 1.5)

            // Window area
            DoorWindowShape()
                .stroke(.gray.opacity(0.25), lineWidth: 1.2)

            // Inner window
            DoorInnerWindowShape()
                .stroke(.gray.opacity(0.2), lineWidth: 0.8)

            // Handle area
            DoorHandleShape()
                .stroke(.gray.opacity(0.35), lineWidth: 1.5)

            // Blue indicator
            VStack(spacing: 0) {
                // Tooltip
                Text("Press to Open Door")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.background, in: .capsule)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 2)

                // Blue button
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 34)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.42, green: 0.68, blue: 0.87),
                                Color(red: 0.29, green: 0.56, blue: 0.77)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: .rect(cornerRadius: 7)
                    )
                    .shadow(color: Color(red: 0.29, green: 0.56, blue: 0.77).opacity(0.3), radius: 8, y: 2)
                    .padding(.top, 4)
            }
            .offset(y: -30)

            // Window controls (bottom right)
            HStack(spacing: 0) {
                Image(systemName: "chevron.up")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .frame(width: 35, height: 50)

                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 0.8, height: 34)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .frame(width: 35, height: 50)
            }
            .background(Color(white: 0.93), in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            .offset(x: 80, y: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect)
    }
}

// MARK: - Door Shapes

/// Outer door panel outline.
private struct DoorPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.08))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.06))
        path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.06, y: h * 0.97))
        path.closeSubpath()
        return path
    }
}

/// Window area at the top of the door.
private struct DoorWindowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.12))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.10),
            control: CGPoint(x: w * 0.5, y: h * 0.08)
        )
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.44))
        path.closeSubpath()
        return path
    }
}

/// Inner window pane.
private struct DoorInnerWindowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.16, y: h * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.14),
            control: CGPoint(x: w * 0.5, y: h * 0.11)
        )
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.39))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.40))
        path.closeSubpath()
        return path
    }
}

/// Door handle outline.
private struct DoorHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        // Horizontal bar
        path.move(to: CGPoint(x: w * 0.22, y: h * 0.48))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.68, y: h * 0.47),
            control: CGPoint(x: w * 0.45, y: h * 0.46)
        )
        // Grip curve down
        path.addQuadCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.58),
            control: CGPoint(x: w * 0.72, y: h * 0.52)
        )
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.50))
        return path
    }
}

// MARK: - Action Buttons

/// Open Trunk and Open Door buttons.
private struct ExitVehicleActionButtons: View {
    var viewModel: TripViewModel
    var onOpenDoor: () -> Void

    @State private var soundPlayer = SoundPlayer()

    var body: some View {
        HStack(spacing: 12) {
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
                .background(.background, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Button {
                onOpenDoor()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "door.left.hand.open")
                        .font(.body)

                    Text("Open Door")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.background, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

