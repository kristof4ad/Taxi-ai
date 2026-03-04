import MapKit
import SwiftUI

/// Screen showing the car approaching the pickup location on a map with trip details below.
struct RideTrackingView: View {
    @Bindable var viewModel: TripViewModel
    var onGoToVehicle: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                RideTrackingMapSection(
                    viewModel: viewModel,
                    isMenuPresented: $isMenuPresented
                )

                RideTrackingBottomCard(viewModel: viewModel, onGoToVehicle: onGoToVehicle)
            }
            .ignoresSafeArea(edges: .top)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .ordering,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
        .onAppear {
            viewModel.startPickupApproach()
        }
    }
}

// MARK: - Map Section

private struct RideTrackingMapSection: View {
    var viewModel: TripViewModel
    @Binding var isMenuPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: .constant(viewModel.cameraPosition)) {
                // Pickup marker — hidden once the car arrives so it doesn't cover the car icon.
                if case .arrivedAtPickup = viewModel.simulationState {
                    // Car is at the pickup stop; don't show the pickup pin.
                } else if let pickupLocation = viewModel.pickupStopLocation ?? viewModel.locationService.userLocation {
                    Annotation("Pickup", coordinate: pickupLocation) {
                        PickupMarkerView()
                    }
                }

                // Dropoff marker at destination
                if let destination = viewModel.destination {
                    Annotation("Dropoff", coordinate: destination) {
                        DropoffMarkerView()
                    }
                }

                // Trip route polyline (to destination)
                if let route = viewModel.route {
                    MapPolyline(route)
                        .stroke(.black.opacity(0.2), lineWidth: 3)
                }

                // Pickup approach route — only the remaining portion ahead of the car
                let remaining = viewModel.remainingPickupRouteCoordinates
                if remaining.count >= 2 {
                    MapPolyline(coordinates: remaining)
                        .stroke(.blue, lineWidth: 5)
                }

                // Animated car marker — shows "Pickup" label underneath when arrived.
                if let carPosition = viewModel.pickupCarPosition {
                    let arrived = {
                        if case .arrivedAtPickup = viewModel.simulationState { return true }
                        return false
                    }()

                    Annotation("", coordinate: carPosition) {
                        CarMarkerView(showPickupLabel: arrived)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard)
            .mapControls {}
            .frame(height: 380)

            VStack(spacing: 12) {
                AppMenuButton(isPresented: $isMenuPresented)
                RouteButton()
            }
            .padding(.top, 62)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Route Button

private struct RouteButton: View {
    var body: some View {
        Button("Route", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath") {
            // Route action placeholder
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .foregroundStyle(.primary)
        .frame(width: 40, height: 40)
        .background(.background, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Bottom Card

private struct RideTrackingBottomCard: View {
    var viewModel: TripViewModel
    var onGoToVehicle: () -> Void

    /// Whether the car has arrived at the pickup location.
    private var hasArrived: Bool {
        if case .arrivedAtPickup = viewModel.simulationState { return true }
        return false
    }

    /// Minutes remaining based on approach progress.
    private var minutesAway: Int {
        if case .approachingPickup(let progress) = viewModel.simulationState {
            return max(1, Int(ceil((1 - progress) * 7)))
        }
        return 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if hasArrived {
                        ArrivedHeader()
                    } else {
                        Text("Your ride is \(minutesAway) min away")
                            .font(.title3.bold())
                    }

                    Text("License Plate:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                        .frame(height: 4)

                    TripTimeline(viewModel: viewModel)

                    Divider()

                    Text("Tips")
                        .font(.callout.weight(.semibold))
                }
                .padding()
            }
            .scrollIndicators(.hidden)

            GoToVehicleButton(isEnabled: hasArrived, action: onGoToVehicle)
                .padding()
        }
        .background(.background)
    }
}

// MARK: - Go to Vehicle Button

private struct GoToVehicleButton: View {
    var isEnabled: Bool
    var action: () -> Void

    /// Gold gradient start color.
    private static let goldStart = Color(red: 0.831, green: 0.659, blue: 0.294)
    /// Gold gradient end color.
    private static let goldEnd = Color(red: 0.722, green: 0.581, blue: 0.290)

    var body: some View {
        Button("Go to Vehicle", action: action)
            .bold()
            .foregroundStyle(isEnabled ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isEnabled
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Self.goldStart, Self.goldEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    : AnyShapeStyle(.quaternary)
            )
            .clipShape(.rect(cornerRadius: 26))
            .disabled(!isEnabled)
            .animation(.easeInOut, value: isEnabled)
    }
}

// MARK: - Arrived Header

private struct ArrivedHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("Your ride has arrived")
                .font(.title3.bold())
        }
    }
}

// MARK: - Trip Timeline

private struct TripTimeline: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Pickup row
            HStack(spacing: 12) {
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pickup")
                        .font(.subheadline.weight(.semibold))

                    Text("Vehicle will wait 7 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(viewModel.estimatedPickupTime, format: .dateTime.hour().minute())
                    .font(.subheadline)
            }
            .padding(.vertical, 8)

            // Connector line
            HStack {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 2, height: 16)
                    .padding(.leading, 5)

                Spacer()
            }

            // Destination row
            HStack(spacing: 12) {
                Circle()
                    .fill(.black)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.destinationName ?? "Destination")
                        .font(.subheadline.weight(.semibold))

                    if let address = viewModel.destinationAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let arrivalTime = viewModel.estimatedArrivalTime {
                    Text(arrivalTime, format: .dateTime.hour().minute())
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
