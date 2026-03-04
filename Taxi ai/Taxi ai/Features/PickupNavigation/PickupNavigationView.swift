import CoreLocation
import SwiftUI

/// Walking navigation screen that guides the user toward the pickup location
/// with a dynamic directional arrow that rotates based on the device's compass heading.
struct PickupNavigationView: View {
    var viewModel: TripViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DirectionSection(
                viewModel: viewModel,
                onDismiss: onDismiss
            )

            PickupNavigationBottomCard(viewModel: viewModel)
        }
        .onAppear {
            viewModel.locationService.startUpdatingHeading()
        }
        .onDisappear {
            viewModel.locationService.stopUpdatingHeading()
        }
    }
}

// MARK: - Direction Section

/// Large arrow and distance display guiding the user toward the pickup pin.
/// The arrow rotates dynamically based on the device compass heading
/// so it always points toward the car's pickup location.
private struct DirectionSection: View {
    var viewModel: TripViewModel
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                Spacer()

                DirectionArrow(viewModel: viewModel)

                Text(distanceText)
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundStyle(.primary)

                Text("Pickup Pin")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)

            CloseButton(action: onDismiss)
                .padding(.top, 62)
                .padding(.leading, 16)
        }
    }

    /// Formatted distance to the pickup stop, using the device's locale units.
    private var distanceText: String {
        guard let user = viewModel.locationService.userLocation,
              let pickup = viewModel.pickupStopLocation else {
            return "--"
        }

        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        let pickupLoc = CLLocation(latitude: pickup.latitude, longitude: pickup.longitude)
        let meters = userLoc.distance(from: pickupLoc)
        let measurement = Measurement(value: meters, unit: UnitLength.meters)

        return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

// MARK: - Direction Arrow

/// An arrow that dynamically rotates to point from the user toward the car's pickup location,
/// compensating for the device's compass heading so it stays accurate as the user turns.
///
/// Uses cumulative rotation tracking (not clamped to 0–360) so the animation always takes
/// the shortest path, and a deadzone filter to suppress sub-degree compass noise.
private struct DirectionArrow: View {
    var viewModel: TripViewModel

    /// Cumulative rotation — not clamped to 0–360 so SwiftUI animations
    /// always interpolate via the shortest arc, never spinning the long way.
    @State private var displayRotation: Double = 0

    /// The last normalized target used to compute shortest-path deltas.
    @State private var previousTarget: Double = 0

    /// Whether the initial heading has been captured (skip animation on first value).
    @State private var isInitialized = false

    var body: some View {
        Image(systemName: "location.north.fill")
            .font(.system(size: 80, weight: .medium))
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(displayRotation))
            .onChange(of: targetRotation) { _, newTarget in
                guard isInitialized else {
                    // Snap to the first value without animation.
                    displayRotation = newTarget
                    previousTarget = newTarget
                    isInitialized = true
                    return
                }

                // Compute the shortest-path delta across the 360°/0° boundary.
                var delta = newTarget - previousTarget
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                previousTarget = newTarget

                // Ignore changes smaller than 1° to suppress residual jitter.
                guard abs(delta) > 1 else { return }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    displayRotation += delta
                }
            }
    }

    /// The desired rotation in degrees, normalized to −180…180.
    ///
    /// Computed as the geographic bearing from the user to the car
    /// minus the device's compass heading.
    private var targetRotation: Double {
        guard let userLocation = viewModel.locationService.userLocation,
              let carLocation = viewModel.pickupStopLocation,
              let heading = viewModel.locationService.userHeading else {
            return 0
        }

        let bearing = userLocation.bearing(to: carLocation)
        var angle = (bearing - heading).truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        return angle
    }

}

// MARK: - Close Button

private struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button("Close", systemImage: "xmark", action: action)
            .labelStyle(.iconOnly)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(.background, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.separator, lineWidth: 1)
            )
    }
}

// MARK: - Bottom Card

private struct PickupNavigationBottomCard: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your ride has arrived")
                        .font(.headline)

                    Text("Walk to the pickup location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Spacer()
                .frame(height: 8)

            NavigationTripTimeline(viewModel: viewModel)

            Divider()

            Text("Tips")
                .font(.callout.weight(.semibold))
        }
        .padding()
        .background(.background)
    }
}

// MARK: - Trip Timeline

private struct NavigationTripTimeline: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Pickup row
            HStack(spacing: 12) {
                Circle()
                    .stroke(.secondary, lineWidth: 2)
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
                    .fill(.quaternary)
                    .frame(width: 2, height: 16)
                    .padding(.leading, 5)

                Spacer()
            }

            // Destination row
            HStack(spacing: 12) {
                Circle()
                    .fill(.primary)
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
