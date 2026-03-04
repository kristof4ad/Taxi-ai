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

// MARK: - Search Bar

private struct SearchBarRow: View {
    @Binding var text: String
    var isActive: Bool
    var onActivate: () -> Void
    var onClear: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Hi, where to?", text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    onClear()
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(.systemGray4), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 24))
        .onTapGesture {
            isFocused = true
        }
        .onChange(of: isActive) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            if newValue {
                onActivate()
            }
        }
    }
}

// MARK: - Search Results Overlay

/// Overlay showing autocomplete suggestions while the user types.
private struct SearchResultsOverlay: View {
    var completions: [SearchCompletion]
    var onSelect: (SearchCompletion) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(completions) { completion in
                    Button {
                        onSelect(completion)
                    } label: {
                        SearchCompletionRow(completion: completion)
                    }
                    .buttonStyle(.plain)

                    Divider()
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(.background)
    }
}

// MARK: - Search Completion Row

private struct SearchCompletionRow: View {
    var completion: SearchCompletion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.subheadline)

                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}

// MARK: - Destination Banner

/// Banner showing the selected destination — tap anywhere to go directly there.
private struct DestinationBanner: View {
    var destination: NearbyPlace
    var onGoDirectly: () -> Void
    var onClear: () -> Void

    var body: some View {
        Button {
            onGoDirectly()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color(red: 0.83, green: 0.66, blue: 0.29))

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
                    .foregroundStyle(Color(red: 0.83, green: 0.66, blue: 0.29))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(red: 0.83, green: 0.66, blue: 0.29).opacity(0.08)
            )
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

// MARK: - Categories Row

private struct CategoriesRow: View {
    var selected: PlaceCategory
    var onSelect: (PlaceCategory) -> Void

    var body: some View {
        HStack {
            ForEach(PlaceCategory.allCases) { category in
                CategoryButton(
                    category: category,
                    isSelected: category == selected,
                    action: { onSelect(category) }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    var category: PlaceCategory
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.systemImage)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected
                            ? Color(red: 0.83, green: 0.66, blue: 0.29).opacity(0.15)
                            : Color(.systemGray6)
                    )
                    .clipShape(.rect(cornerRadius: 16))

                Text(category.label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isSelected ? Color(red: 0.83, green: 0.66, blue: 0.29) : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Places List

private struct PlacesList: View {
    var places: [NearbyPlace]
    var onSelect: (NearbyPlace) -> Void

    var body: some View {
        ForEach(places) { place in
            Button {
                onSelect(place)
            } label: {
                PlaceRow(place: place)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Place Row

private struct PlaceRow: View {
    var place: NearbyPlace

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))

                Text(place.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(place.formattedDistance)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(),
        onPlaceSelected: { _ in },
        onShowRideHistory: { }
    )
}
