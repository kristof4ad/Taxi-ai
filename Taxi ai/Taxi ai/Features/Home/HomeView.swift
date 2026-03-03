import MapKit
import SwiftUI

/// The main home screen showing a map, search bar, categories, and nearby places.
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    var onPlaceSelected: (NearbyPlace) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HomeMapSection(cameraPosition: $viewModel.cameraPosition)

            BottomSheetSection(
                viewModel: viewModel,
                onPlaceSelected: onPlaceSelected
            )
        }
        .ignoresSafeArea(edges: .top)
        .task {
            viewModel.onAppear()
            await viewModel.loadInitialPlaces()
        }
    }
}

// MARK: - Map Section

private struct HomeMapSection: View {
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {}
            .frame(height: 420)

            MenuButton()
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
        .frame(width: 44, height: 44)
        .background(.background, in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Bottom Sheet

private struct BottomSheetSection: View {
    var viewModel: HomeViewModel
    var onPlaceSelected: (NearbyPlace) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SearchBarRow()

                ArrivalBanner(minutes: viewModel.estimatedArrival)

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
    }
}

// MARK: - Search Bar

private struct SearchBarRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            Text("Hi, where to?")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(.systemGray4), lineWidth: 1)
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
        onPlaceSelected: { _ in }
    )
}
