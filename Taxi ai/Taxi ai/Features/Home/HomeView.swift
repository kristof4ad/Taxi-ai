import MapKit
import SwiftUI

/// The main home screen showing a map, search bar, categories, and nearby places.
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    var onPlaceSelected: (NearbyPlace) -> Void
    var onShowRideHistory: () -> Void

    @Environment(IntelligenceService.self) private var intelligenceService
    @State private var isMenuPresented = false
    @State private var isVoiceSheetPresented = false
    @State private var voiceService = VoiceTranscriptionService()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HomeMapSection(
                    cameraPosition: $viewModel.cameraPosition,
                    selectedDestination: viewModel.selectedDestination,
                    isMenuPresented: $isMenuPresented
                )

                BottomSheetSection(
                    viewModel: viewModel,
                    onPlaceSelected: onPlaceSelected,
                    // Only show the AI mic pill on devices that can actually
                    // run the on-device model. On A14 and earlier (e.g.
                    // iPhone 12 mini) voice-only dictation into a literal
                    // MapKit search is worse than the regular keyboard.
                    onAITapped: intelligenceService.isAvailable
                        ? { isVoiceSheetPresented = true }
                        : nil
                )
            }
            .ignoresSafeArea(edges: .top)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .none,
                onCancel: { },
                onShowRideHistory: onShowRideHistory
            )
        }
        .task {
            viewModel.intelligenceService = intelligenceService
            viewModel.onAppear()
            await viewModel.loadInitialPlaces()
        }
        .alert("Destination Too Far", isPresented: $viewModel.showTooFarAlert) {
            Button("OK") { }
        } message: {
            Text("This destination is more than 30 miles away. Our taxi service cannot reach it.")
        }
        .sheet(isPresented: $isVoiceSheetPresented, onDismiss: {
            // `reset()` already stops the recorder and clears state;
            // calling `stop()` as well races with `reset()` and leaves the
            // service stuck in `.finished`, which breaks the next open.
            voiceService.reset()
        }, content: {
            VoiceSearchSheet(
                service: voiceService,
                onSubmit: { transcript in
                    isVoiceSheetPresented = false
                    // Wait for the sheet's dismissal animation to finish so
                    // focusing the search bar doesn't fight the transition
                    // and leave the home layout half-settled.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        await viewModel.submitVoiceQuery(transcript)
                    }
                },
                onDismiss: {
                    isVoiceSheetPresented = false
                }
            )
        })
    }
}

// MARK: - Map Section

private struct HomeMapSection: View {
    @Binding var cameraPosition: MapCameraPosition
    var selectedDestination: NearbyPlace?
    @Binding var isMenuPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let destination = selectedDestination {
                    Annotation(destination.name, coordinate: destination.coordinate) {
                        DestinationMarkerView()
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {}
            .frame(height: 420)

            AppMenuButton(isPresented: $isMenuPresented)
                .padding(.top, 62)
                .padding(.trailing, 16)
        }
    }
}

// MARK: - Bottom Sheet

private struct BottomSheetSection: View {
    @Bindable var viewModel: HomeViewModel
    var onPlaceSelected: (NearbyPlace) -> Void
    /// Optional — `nil` hides the AI mic pill on devices without Apple
    /// Intelligence support.
    var onAITapped: (() -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 12) {
                    SearchBarRow(
                        text: $viewModel.searchText,
                        isActive: viewModel.isSearchActive,
                        onActivate: { viewModel.isSearchActive = true },
                        onClear: { viewModel.clearSearch() }
                    )
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.updateSearchText(newValue)
                    }

                    if let destination = viewModel.selectedDestination {
                        DestinationBanner(
                            destination: destination,
                            onGoDirectly: { onPlaceSelected(destination) },
                            onClear: { viewModel.clearSearch() }
                        )
                    }

                    ArrivalBanner(minutes: viewModel.estimatedArrival)

                    CategoriesRow(
                        selected: viewModel.selectedCategory,
                        onSelect: { viewModel.selectCategory($0) },
                        onAITapped: onAITapped
                    )

                    if viewModel.selectedDestination != nil {
                        Text("Places nearby")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    if viewModel.isSearching {
                        ProgressView()
                            .padding(.vertical)
                    } else {
                        PlacesList(
                            places: viewModel.nearbyPlaces,
                            onSelect: onPlaceSelected
                        )
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(.background)

            // Search overlay when actively typing
            if viewModel.isSearchActive && !viewModel.searchText.isEmpty {
                SearchResultsOverlay(
                    completions: viewModel.currentCompletions,
                    onSelect: { completion in
                        Task {
                            await viewModel.selectSearchCompletion(completion)
                        }
                    }
                )
                .padding(.top, 64)
            }
        }
    }
}

// MARK: - Arrival Banner

private struct ArrivalBanner: View {
    var minutes: Int

    var body: some View {
        Text("A ride can arrive in \(minutes) min")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(LinearGradient.taxiGoldHorizontal)
            .clipShape(.rect(cornerRadius: 18))
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(),
        onPlaceSelected: { _ in },
        onShowRideHistory: { }
    )
    .environment(IntelligenceService())
}
