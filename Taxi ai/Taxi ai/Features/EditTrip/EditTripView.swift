import MapKit
import SwiftUI

/// Modal sheet for changing the trip destination mid-ride.
/// Shows a map with the current route, a search bar, categories, and nearby places.
struct EditTripView: View {
    var tripViewModel: TripViewModel
    @Bindable var viewModel: EditTripViewModel
    var onConfirm: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                EditTripMapSection(tripViewModel: tripViewModel)

                EditTripSearchSection(
                    viewModel: viewModel,
                    onPlaceSelected: { place in
                        Task {
                            await viewModel.selectNewDestination(place)
                        }
                    }
                )
            }

            if viewModel.showPriceConfirmation, let destination = viewModel.newDestination {
                EditTripPriceConfirmation(
                    destinationName: destination.name,
                    destinationAddress: destination.address,
                    newPrice: viewModel.newEstimatedPrice,
                    priceDifference: viewModel.priceDifference,
                    currencyCode: viewModel.displayCurrencyCode,
                    isCalculating: viewModel.isCalculatingRoute,
                    onConfirm: {
                        Task {
                            guard let destination = viewModel.newDestination else { return }
                            await tripViewModel.changeDestination(to: destination)
                            onConfirm()
                        }
                    },
                    onCancel: {
                        viewModel.clearSearch()
                    }
                )
            }
        }
        .alert("Destination Too Far", isPresented: $viewModel.showTooFarAlert) {
            Button("OK") { }
        } message: {
            Text("This destination is more than 30 miles away. Our taxi service cannot reach it.")
        }
        .task {
            await viewModel.loadInitialPlaces()
        }
    }
}

// MARK: - Map Section

/// Map showing the current route and taxi position.
private struct EditTripMapSection: View {
    var tripViewModel: TripViewModel

    var body: some View {
        Map(position: .constant(tripViewModel.cameraPosition)) {
            if let destination = tripViewModel.destination {
                Annotation("Destination", coordinate: destination) {
                    DestinationMarkerView()
                }
            }

            if let route = tripViewModel.route {
                MapPolyline(route)
                    .stroke(.blue, lineWidth: 5)
            }

            if let position = tripViewModel.simulationEngine.currentPosition {
                Annotation("Taxi", coordinate: position) {
                    CarMarkerView()
                }
            }

            UserAnnotation()
        }
        .mapStyle(.standard)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .frame(height: 300)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Search Section

/// Bottom section with search bar, categories, and places list.
private struct EditTripSearchSection: View {
    @Bindable var viewModel: EditTripViewModel
    var onPlaceSelected: (NearbyPlace) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 12) {
                    SearchBarRow(
                        text: $viewModel.searchText,
                        placeholder: "Change destination",
                        isActive: viewModel.isSearchActive,
                        onActivate: { viewModel.isSearchActive = true },
                        onClear: { viewModel.clearSearch() }
                    )
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.updateSearchText(newValue)
                    }

                    CategoriesRow(
                        selected: viewModel.selectedCategory,
                        onSelect: { viewModel.selectCategory($0) }
                    )

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
