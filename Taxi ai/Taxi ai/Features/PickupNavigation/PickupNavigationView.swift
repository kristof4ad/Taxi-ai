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

                DirectionArrowView(
                    userLocation: viewModel.locationService.userLocation,
                    targetLocation: viewModel.pickupStopLocation,
                    userHeading: viewModel.locationService.userHeading
                )

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

// MARK: - Close Button

private struct CloseButton: View {
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
