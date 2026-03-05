import MapKit
import SwiftUI

/// Main map view with destination selection, route display, and ride simulation.
struct MapView: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            mapContent

            if viewModel.showControlPanel {
                ControlPanelView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            }

            // Instruction overlay when selecting destination
            if viewModel.simulationState == .selectingDestination
                && viewModel.destination == nil {
                instructionBanner
            }

            // Loading indicator while calculating route
            if viewModel.simulationState == .calculatingRoute {
                calculatingOverlay
            }
        }
        .animation(.default, value: viewModel.showControlPanel)
        .animation(.default, value: viewModel.simulationState)
        .alert(
            "Error",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .alert(
            "Location Access Required",
            isPresented: .init(
                get: { viewModel.locationDenied },
                set: { _ in }
            )
        ) {
            Button("Open Settings", systemImage: "gear") {
                if let url = URL(string: "App-Prefs:root") {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access in Settings to use Taxi AI.")
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Subviews

extension MapView {
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition) {
                // Destination pin
                if let destination = viewModel.destination {
                    Annotation("Destination", coordinate: destination) {
                        DestinationMarkerView()
                    }
                }

                // Route polyline
                if let route = viewModel.route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }

                // Simulation dot
                if let position = viewModel.simulationEngine.currentPosition {
                    Annotation("", coordinate: position) {
                        SimulationDotView()
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .mapStyle(.standard)
            .onTapGesture { screenCoord in
                guard let coordinate = proxy.convert(screenCoord, from: .local) else {
                    return
                }
                viewModel.selectDestination(coordinate)
            }
        }
    }

    private var instructionBanner: some View {
        VStack {
            Text("Tap on the map to select your destination")
                .font(.subheadline)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 12))
                .padding(.top)

            Spacer()
        }
    }

    private var calculatingOverlay: some View {
        VStack {
            Spacer()

            HStack {
                ProgressView()
                Text("Calculating route...")
                    .font(.subheadline)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 12))
            .padding(.bottom, 100)
        }
    }
}
