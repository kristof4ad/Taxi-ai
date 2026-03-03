import MapKit
import SwiftUI

/// Screen showing the car approaching the pickup location on a map with trip details below.
struct RideTrackingView: View {
    @Bindable var viewModel: TripViewModel

    var body: some View {
        VStack(spacing: 0) {
            RideTrackingMapSection(viewModel: viewModel)

            RideTrackingBottomCard(viewModel: viewModel)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.startPickupApproach()
        }
    }
}

// MARK: - Map Section

private struct RideTrackingMapSection: View {
    var viewModel: TripViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: .constant(viewModel.cameraPosition)) {
                // Pickup marker at user location
                if let userLocation = viewModel.locationService.userLocation {
                    Annotation("Pickup", coordinate: userLocation) {
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

                // Animated car marker
                if let carPosition = viewModel.pickupCarPosition {
                    Annotation("", coordinate: carPosition) {
                        CarMarkerView()
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard)
            .mapControls {}
            .frame(height: 380)

            VStack(spacing: 12) {
                MenuButton()
                RouteButton()
            }
            .padding(.top, 62)
            .padding(.trailing, 16)
        }
    }
}

// MARK: - Menu Button

private struct MenuButton: View {
    var body: some View {
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

    /// Minutes remaining based on approach progress.
    private var minutesAway: Int {
        if case .approachingPickup(let progress) = viewModel.simulationState {
            return max(1, Int(ceil((1 - progress) * 7)))
        }
        return 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if case .arrivedAtPickup = viewModel.simulationState {
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
        .background(.background)
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
