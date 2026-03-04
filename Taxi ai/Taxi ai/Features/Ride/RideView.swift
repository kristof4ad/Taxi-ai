import MapKit
import SwiftUI

/// Active ride screen showing the map with destination header and action buttons.
/// Provides a consistent layout matching the rest of the app.
struct RideView: View {
    @Bindable var viewModel: TripViewModel
    var onArrived: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RideTopSection(viewModel: viewModel)

            RideMapSection(viewModel: viewModel)

            RideActionButtons()
        }
        .background(.background)
        .onAppear {
            viewModel.startRide()
        }
        .onChange(of: viewModel.simulationState) { _, newState in
            if newState == .completed {
                withAnimation {
                    onArrived()
                }
            }
        }
    }
}

// MARK: - Top Section

/// Menu button and destination heading.
private struct RideTopSection: View {
    var viewModel: TripViewModel

    private static let goldText = Color(red: 0.831, green: 0.659, blue: 0.294)

    var body: some View {
        VStack(spacing: 0) {
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

            VStack(spacing: 4) {
                Text("Heading to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.destinationName ?? "Destination")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Self.goldText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Map Section

/// Interactive map displaying the route, destination, and simulation position.
private struct RideMapSection: View {
    @Bindable var viewModel: TripViewModel

    var body: some View {
        Map(position: $viewModel.cameraPosition) {
            if let destination = viewModel.destination {
                Annotation("Destination", coordinate: destination) {
                    DestinationMarkerView()
                }
            }

            if let route = viewModel.route {
                MapPolyline(route)
                    .stroke(.blue, lineWidth: 5)
            }

            if let position = viewModel.simulationEngine.currentPosition {
                Annotation("Taxi", coordinate: position) {
                    CarMarkerView()
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

// MARK: - Action Buttons

/// Edit Trip and Lock buttons at the bottom.
private struct RideActionButtons: View {
    var body: some View {
        HStack(spacing: 12) {
            RideActionButton(title: "Edit Trip", icon: "pencil")
            RideActionButton(title: "Lock", icon: "lock")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Action Button

private struct RideActionButton: View {
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
