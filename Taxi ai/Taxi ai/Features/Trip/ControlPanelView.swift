import SwiftUI

/// Bottom panel displaying route information and action buttons.
struct ControlPanelView: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack {
            // Route information
            if let info = viewModel.tripInfo {
                RouteInfoView(info: info)
            }

            // Progress or completion status
            SimulationStatusView(state: viewModel.simulationState)

            // Action buttons
            ActionButtonsView(viewModel: viewModel)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .padding()
    }
}

/// Displays route distance and estimated travel time.
struct RouteInfoView: View {
    let info: TripInfo

    var body: some View {
        HStack {
            Label {
                Text(
                    Measurement(value: info.distance, unit: UnitLength.meters),
                    format: .measurement(width: .abbreviated)
                )
            } icon: {
                Image(systemName: "car.fill")
            }

            Spacer()

            Label {
                Text(
                    Duration.seconds(info.expectedTravelTime),
                    format: .time(pattern: .minuteSecond)
                )
            } icon: {
                Image(systemName: "clock.fill")
            }
        }
        .font(.subheadline)
    }
}

/// Shows progress bar during simulation or completion indicator.
struct SimulationStatusView: View {
    let state: SimulationState

    var body: some View {
        switch state {
        case .simulating(let progress):
            ProgressView(value: progress)
                .tint(.blue)

        case .completed:
            Label("Arrived!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)

        default:
            EmptyView()
        }
    }
}

/// Renders the appropriate action button for the current state.
struct ActionButtonsView: View {
    var viewModel: TripViewModel

    var body: some View {
        HStack {
            if viewModel.simulationState == .routeReady {
                Button("Start Ride", systemImage: "play.fill") {
                    viewModel.startSimulation()
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.simulationState == .completed {
                Button("New Trip", systemImage: "arrow.counterclockwise") {
                    viewModel.resetTrip()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
