import MapKit
import SwiftUI

/// The main home screen showing a map, search bar, categories, and nearby places.
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    var onPlaceSelected: (NearbyPlace) -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

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
                    onPlaceSelected: onPlaceSelected
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
            viewModel.onAppear()
            await viewModel.loadInitialPlaces()
        }
        .alert("Destination Too Far", isPresented: $viewModel.showTooFarAlert) {
            Button("OK") { }
        } message: {
            Text("This destination is more than 30 miles away. Our taxi service cannot reach it.")
        }
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
                        onSelect: { viewModel.selectCategory($0) }
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

// MARK: - Destination Banner

/// Banner showing the selected destination — tap anywhere to go directly there.
private struct DestinationBanner: View {
    var destination: NearbyPlace
    var onGoDirectly: () -> Void
    var onClear: () -> Void

    private static let gold = Color(red: 0.83, green: 0.66, blue: 0.29)

    var body: some View {
        Button {
            onGoDirectly()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Self.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name)
                        .font(.subheadline.weight(.semibold))

                    if !destination.address.isEmpty {
                        Text(destination.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Self.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Self.gold.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.83, green: 0.66, blue: 0.29),
                        Color(red: 0.72, green: 0.58, blue: 0.29)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 18))
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(),
        onPlaceSelected: { _ in },
        onShowRideHistory: { }
    )
}
