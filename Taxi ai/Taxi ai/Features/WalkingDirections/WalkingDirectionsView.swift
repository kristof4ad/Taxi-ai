import CoreLocation
import MapKit
import SwiftUI

/// Sheet showing a map with walking directions from the drop-off location to the final destination.
/// Mirrors the layout of `EnterVehicleView` with a map, walking route polyline, and a bottom card.
struct WalkingDirectionsView: View {
    var viewModel: TripViewModel
    var onDismiss: () -> Void

    @State private var walkingRoute: MKRoute?
    @State private var showFindDestination = false

    var body: some View {
        ZStack(alignment: .bottom) {
            WalkingDirectionsMapSection(
                viewModel: viewModel,
                walkingRoute: walkingRoute
            )
            .ignoresSafeArea(edges: .top)

            WalkingDirectionsBottomCard(
                viewModel: viewModel,
                walkingRoute: walkingRoute,
                onFindDestination: { showFindDestination = true },
                onDismiss: onDismiss
            )
        }
        .presentationDragIndicator(.visible)
        .task {
            await calculateWalkingRoute()
        }
        .fullScreenCover(isPresented: $showFindDestination) {
            FindDestinationView(
                viewModel: viewModel,
                walkingRoute: walkingRoute,
                onDismiss: { showFindDestination = false }
            )
        }
    }

    /// Calculates a walking route from the drop-off location to the final destination.
    private func calculateWalkingRoute() async {
        guard let dropOff = viewModel.dropOffLocation,
              let destination = viewModel.destination else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: dropOff.latitude, longitude: dropOff.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: destination.latitude, longitude: destination.longitude),
            address: nil
        )
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

/// Map showing the car's stop position, the destination marker, and the walking route between them.
private struct WalkingDirectionsMapSection: View {
    var viewModel: TripViewModel
    var walkingRoute: MKRoute?

    var body: some View {
        Map(position: .constant(cameraPosition)) {
            // Car stopped here
            if let dropOff = viewModel.dropOffLocation {
                Annotation("Car", coordinate: dropOff) {
                    CarMarkerView()
                }
                .annotationTitles(.hidden)
            }

            // Final destination
            if let destination = viewModel.destination {
                Annotation("Destination", coordinate: destination) {
                    DropoffMarkerView(name: viewModel.destinationName ?? "Destination")
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
    }

    /// Camera position zoomed in tightly to fit the car stop and the destination (~300 m apart).
    private var cameraPosition: MapCameraPosition {
        if let dropOff = viewModel.dropOffLocation,
           let destination = viewModel.destination {
            let midLat = (dropOff.latitude + destination.latitude) / 2
            let midLon = (dropOff.longitude + destination.longitude) / 2
            let center = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

            let latDelta = abs(dropOff.latitude - destination.latitude) * 2.5
            let lonDelta = abs(dropOff.longitude - destination.longitude) * 2.5
            let span = MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.003),
                longitudeDelta: max(lonDelta, 0.003)
            )

            return .region(MKCoordinateRegion(center: center, span: span))
        } else if let destination = viewModel.destination {
            return .camera(MapCamera(centerCoordinate: destination, distance: 600))
        } else {
            return .userLocation(fallback: .automatic)
        }
    }
}

// MARK: - Bottom Card

/// Bottom card with destination info, find destination button, and close button.
private struct WalkingDirectionsBottomCard: View {
    var viewModel: TripViewModel
    var walkingRoute: MKRoute?
    var onFindDestination: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WalkingDirectionsHeader(walkingRoute: walkingRoute, onFindDestination: onFindDestination)

            Divider()

            DestinationLocationRow(viewModel: viewModel)

            WalkingDirectionsCloseButton(onDismiss: onDismiss)
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

private struct WalkingDirectionsHeader: View {
    var walkingRoute: MKRoute?
    var onFindDestination: () -> Void

    /// Formatted walking distance from the route.
    private var distanceText: String? {
        guard let distance = walkingRoute?.distance else { return nil }
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Walk to your destination")
                    .font(.title3.bold())

                if let distanceText {
                    Text("\(distanceText) walk")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Follow the route on the map")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Find Destination", systemImage: "arrow.up.right", action: onFindDestination)
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
}

// MARK: - Destination Location Row

private struct DestinationLocationRow: View {
    var viewModel: TripViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(.primary)

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
        }
    }
}

// MARK: - Close Button

private struct WalkingDirectionsCloseButton: View {
    var onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Text("Close")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(.rect(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.quaternary, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Find Destination View

/// Full-screen compass view that guides the user toward the final destination
/// with a dynamic directional arrow, similar to `PickupNavigationView`.
private struct FindDestinationView: View {
    var viewModel: TripViewModel
    var walkingRoute: MKRoute?
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FindDestinationDirectionSection(
                viewModel: viewModel,
                walkingRoute: walkingRoute,
                onDismiss: onDismiss
            )

            FindDestinationBottomCard(viewModel: viewModel)
        }
        .onAppear {
            viewModel.locationService.startUpdatingHeading()
        }
        .onDisappear {
            viewModel.locationService.stopUpdatingHeading()
        }
    }
}

// MARK: - Find Destination Direction Section

/// Arrow and distance display pointing toward the destination.
private struct FindDestinationDirectionSection: View {
    var viewModel: TripViewModel
    var walkingRoute: MKRoute?
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                Spacer()

                DirectionArrowView(
                    userLocation: viewModel.locationService.userLocation,
                    targetLocation: viewModel.destination,
                    userHeading: viewModel.locationService.userHeading
                )

                Text(distanceText)
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundStyle(.primary)

                Text(viewModel.destinationName ?? "Destination")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)

            FindDestinationCloseButton(action: onDismiss)
                .padding(.top, 62)
                .padding(.leading, 16)
        }
    }

    /// Formatted walking distance from the route, matching the map sheet display.
    private var distanceText: String {
        guard let distance = walkingRoute?.distance else { return "--" }
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

// MARK: - Find Destination Close Button

private struct FindDestinationCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button("Close", systemImage: "xmark", action: action)
            .labelStyle(.iconOnly)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .contentShape(.rect(cornerRadius: 22))
            .background(.background, in: .rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.separator, lineWidth: 1)
            )
            .buttonStyle(.plain)
    }
}

// MARK: - Find Destination Bottom Card

private struct FindDestinationBottomCard: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Walk to your destination")
                        .font(.headline)

                    Text(viewModel.destinationName ?? "Destination")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Spacer()
                .frame(height: 8)

            if let address = viewModel.destinationAddress {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)

                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background)
    }
}
