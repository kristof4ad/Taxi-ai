import MapKit
import SwiftUI

/// Active ride screen showing the map with destination header and action buttons.
/// Provides a consistent layout matching the rest of the app.
struct RideView: View {
    @Bindable var viewModel: TripViewModel
    var onArrived: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false
    @State private var showEditTrip = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                RideTopSection(
                    viewModel: viewModel,
                    isMenuPresented: $isMenuPresented
                )

                RideMapSection(viewModel: viewModel)

                RideActionButtons(onEditTrip: { showEditTrip = true })
            }
            .background(.background)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .riding,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
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
        .sheet(isPresented: $showEditTrip, onDismiss: {
            viewModel.simulationEngine.resume()
        }) {
            if let origin = viewModel.currentRouteOrigin {
                EditTripView(
                    tripViewModel: viewModel,
                    viewModel: EditTripViewModel(
                        locationService: viewModel.locationService,
                        currencyService: viewModel.currencyService,
                        originalPrice: viewModel.estimatedPrice,
                        routeOrigin: origin,
                        distanceAlreadyDriven: viewModel.totalDistanceDriven,
                        minimumPrice: viewModel.minimumRidePrice
                    ),
                    onConfirm: { showEditTrip = false },
                    onDismiss: { showEditTrip = false }
                )
            }
        }
        .onChange(of: showEditTrip) { _, isShowing in
            if isShowing {
                viewModel.simulationEngine.pause()
            }
        }
    }
}

// MARK: - Top Section

/// Menu button and destination heading.
private struct RideTopSection: View {
    var viewModel: TripViewModel
    @Binding var isMenuPresented: Bool

    private static let goldText = Color(red: 0.831, green: 0.659, blue: 0.294)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                AppMenuButton(isPresented: $isMenuPresented)
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
    var onEditTrip: () -> Void

    @State private var isLocked = true
    @State private var soundPlayer = SoundPlayer()

    var body: some View {
        HStack(spacing: 12) {
            RideActionButton(title: "Edit Trip", icon: "pencil", action: onEditTrip)
            RideActionButton(
                title: isLocked ? "Lock" : "Unlock",
                icon: isLocked ? "lock" : "lock.open",
                action: {
                    soundPlayer.playLock()
                    isLocked.toggle()
                }
            )
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
