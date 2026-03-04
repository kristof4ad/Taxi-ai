import CoreLocation
import MapKit
import SwiftUI

/// Screen shown after the car has arrived, prompting the user to walk to and enter the vehicle.
struct EnterVehicleView: View {
    var viewModel: TripViewModel
    var onFindVehicle: () -> Void
    var onOpenDoor: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var walkingRoute: MKRoute?
    @State private var isMenuPresented = false
    @State private var flashTrigger = 0
    @State private var hazardTrigger = 0
    @State private var soundPlayer = SoundPlayer()

    var body: some View {
        ZStack(alignment: .bottom) {
            EnterVehicleMapSection(
                viewModel: viewModel,
                walkingRoute: walkingRoute,
                isMenuPresented: $isMenuPresented
            )
            .ignoresSafeArea(edges: .top)

            EnterVehicleBottomSheet(
                viewModel: viewModel,
                onFindVehicle: onFindVehicle,
                onOpenDoor: onOpenDoor,
                onHorn: { soundPlayer.playHorn() },
                onLights: { flashTrigger += 1 },
                onUnlock: { soundPlayer.playLock() },
                onHazard: { hazardTrigger += 1 }
            )

            HeadlightFlashOverlay(trigger: flashTrigger)
            HazardBlinkOverlay(trigger: hazardTrigger)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .ordering,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
        .task {
            await calculateWalkingRoute()
        }
    }

    /// Calculates a walking route from the user's location to the car's pickup stop.
    private func calculateWalkingRoute() async {
        guard let userLocation = viewModel.locationService.userLocation,
              let carLocation = viewModel.pickupStopLocation else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: carLocation.latitude, longitude: carLocation.longitude), address: nil)
        request.transportType = .walking

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            walkingRoute = response.routes.first
        } catch {
            // Silently fail — the map still shows both markers without the route.
        }
    }
}

// MARK: - Map Section

/// Close-up map showing the user's position, the arrived car, and the walking route between them.
private struct EnterVehicleMapSection: View {
    var viewModel: TripViewModel
    var walkingRoute: MKRoute?
    @Binding var isMenuPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: .constant(cameraPosition)) {
                // User location marker
                if let userLocation = viewModel.locationService.userLocation {
                    Annotation("You", coordinate: userLocation) {
                        UserLocationMarker()
                    }
                    .annotationTitles(.hidden)
                }

                // Car at pickup stop
                if let carPosition = viewModel.pickupStopLocation {
                    Annotation("Car", coordinate: carPosition) {
                        CarMarkerView(showPickupLabel: true)
                    }
                    .annotationTitles(.hidden)
                }

                // Walking route polyline
                if let walkingRoute {
                    MapPolyline(walkingRoute)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard)
            .mapControls {}

            VStack(spacing: 12) {
                AppMenuButton(isPresented: $isMenuPresented)
            }
            .padding(.top, 62)
            .padding(.trailing, 16)
        }
    }

    /// Camera position that fits both the user and the car.
    private var cameraPosition: MapCameraPosition {
        if let user = viewModel.locationService.userLocation,
           let car = viewModel.pickupStopLocation {
            let midLat = (user.latitude + car.latitude) / 2
            let midLon = (user.longitude + car.longitude) / 2
            let center = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

            let latDelta = abs(user.latitude - car.latitude) * 2.5
            let lonDelta = abs(user.longitude - car.longitude) * 2.5
            let span = MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.003),
                longitudeDelta: max(lonDelta, 0.003)
            )

            return .region(MKCoordinateRegion(center: center, span: span))
        } else if let stop = viewModel.pickupStopLocation {
            return .camera(MapCamera(centerCoordinate: stop, distance: 600))
        } else {
            return .userLocation(fallback: .automatic)
        }
    }
}

// MARK: - User Location Marker

private struct UserLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.15))
                .frame(width: 44, height: 44)

            Circle()
                .fill(.blue)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(.white, lineWidth: 3)
                )
        }
    }
}

// MARK: - Bottom Sheet

private struct EnterVehicleBottomSheet: View {
    var viewModel: TripViewModel
    var onFindVehicle: () -> Void
    var onOpenDoor: () -> Void
    var onHorn: () -> Void
    var onLights: () -> Void
    var onUnlock: () -> Void
    var onHazard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EnterVehicleHeader(onFindVehicle: onFindVehicle)

            VehicleActionButtons(
                onHorn: onHorn,
                onLights: onLights,
                onUnlock: onUnlock,
                onHazard: onHazard
            )

            Divider()

            PickupLocationRow(viewModel: viewModel)

            OpenDoorButton(action: onOpenDoor)
        }
        .padding()
        .background(
            .background,
            in: .rect(cornerRadii: .init(topLeading: 24, topTrailing: 24))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
    }
}

// MARK: - Header

private struct EnterVehicleHeader: View {
    var onFindVehicle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Please walk to vehicle")
                    .font(.title3.bold())

                Text("Vehicle will wait 7 min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            FindVehicleButton(action: onFindVehicle)
        }
    }
}

// MARK: - Find Vehicle Button

private struct FindVehicleButton: View {
    var action: () -> Void

    var body: some View {
        Button("Find Vehicle", systemImage: "arrow.up.right", action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.separator, lineWidth: 1)
            )
            .buttonStyle(.plain)
    }
}

// MARK: - Vehicle Action Buttons

/// Row of circular action buttons for interacting with the vehicle.
private struct VehicleActionButtons: View {
    var onHorn: () -> Void
    var onLights: () -> Void
    var onUnlock: () -> Void
    var onHazard: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            VehicleActionButton(title: "Horn", icon: "speaker.wave.2", action: onHorn)
            VehicleActionButton(title: "Lights", icon: "lightbulb", action: onLights)
            VehicleActionButton(title: "Unlock", icon: "lock", action: onUnlock)
            VehicleActionButton(title: "Hazard", icon: "exclamationmark.triangle", action: onHazard)
            Spacer()
        }
    }
}

private struct VehicleActionButton: View {
    var title: String
    var icon: String
    var action: () -> Void

    var body: some View {
        Button(title, systemImage: icon, action: action)
            .labelStyle(.iconOnly)
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .contentShape(.circle)
            .background(.fill, in: .circle)
            .buttonStyle(.plain)
    }
}

// MARK: - Pickup Location Row

private struct PickupLocationRow: View {
    var viewModel: TripViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.destinationName ?? "Pickup Location")
                    .font(.subheadline.weight(.semibold))

                if let address = viewModel.destinationAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.estimatedPickupTime, format: .dateTime.hour().minute())
                    .font(.subheadline)

                Text("+2 min walk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Open Door Button

private struct OpenDoorButton: View {
    var action: () -> Void

    /// Gold gradient start color.
    private static let goldStart = Color(red: 0.831, green: 0.659, blue: 0.294)
    /// Gold gradient end color.
    private static let goldEnd = Color(red: 0.722, green: 0.581, blue: 0.290)

    var body: some View {
        Button(action: action) {
            Text("Open the door")
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
}
