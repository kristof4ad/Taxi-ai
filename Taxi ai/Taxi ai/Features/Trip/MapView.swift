import MapKit
import SwiftUI

/// Main map view with destination selection, route display, and ride simulation.
struct MapView: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.openURL) private var openURL

    /// Mirrors `viewModel.locationDenied` so dismissing the alert actually sticks;
    /// a binding derived straight from the view model can never be set back.
    @State private var isLocationAlertPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MapContent(viewModel: viewModel)

            if viewModel.showControlPanel {
                ControlPanelView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            }

            // Instruction overlay when selecting destination
            if viewModel.simulationState == .selectingDestination
                && viewModel.destination == nil {
                MapInstructionBanner()
            }

            // Loading indicator while calculating route
            if viewModel.simulationState == .calculatingRoute {
                MapCalculatingOverlay()
            }
        }
        .animation(.default, value: viewModel.showControlPanel)
        .animation(.default, value: viewModel.simulationState)
        .alert("Error", isPresented: $viewModel.hasError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .alert("Location Access Required", isPresented: $isLocationAlertPresented) {
            Button("Open Settings", systemImage: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access in Settings to use Taxi AI.")
        }
        .onChange(of: viewModel.locationDenied) { _, isDenied in
            if isDenied { isLocationAlertPresented = true }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Map Content

private struct MapContent: View {
    @Bindable var viewModel: TripViewModel

    var body: some View {
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
}

// MARK: - Instruction Banner

private struct MapInstructionBanner: View {
    var body: some View {
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
}

// MARK: - Calculating Overlay

private struct MapCalculatingOverlay: View {
    var body: some View {
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
