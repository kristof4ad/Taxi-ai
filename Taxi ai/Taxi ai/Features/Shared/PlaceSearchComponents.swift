import MapKit
import SwiftUI

// MARK: - Search Bar

/// A search bar with a magnifying glass icon, text field, and clear button.
struct SearchBarRow: View {
    @Binding var text: String
    var placeholder: String = "Hi, where to?"
    var isActive: Bool
    var onActivate: () -> Void
    var onClear: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            // Fills the pill so the whole row acts as the field's hit target,
            // which avoids needing a tap gesture that VoiceOver can't reach.
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .stroke(.quaternary, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 24))
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
struct SearchResultsOverlay: View {
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

/// A single autocomplete suggestion row with icon, title, and subtitle.
struct SearchCompletionRow: View {
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

// MARK: - Categories Row

/// Horizontal row of category filter buttons, optionally with an AI voice-search pill.
struct CategoriesRow: View {
    var selected: PlaceCategory
    var onSelect: (PlaceCategory) -> Void
    var onAITapped: (() -> Void)?

    init(
        selected: PlaceCategory,
        onSelect: @escaping (PlaceCategory) -> Void,
        onAITapped: (() -> Void)? = nil
    ) {
        self.selected = selected
        self.onSelect = onSelect
        self.onAITapped = onAITapped
    }

    var body: some View {
        HStack {
            ForEach(PlaceCategory.allCases) { category in
                CategoryButton(
                    category: category,
                    isSelected: category == selected,
                    action: { onSelect(category) }
                )
            }

            if let onAITapped {
                AICategoryButton(action: onAITapped)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Button

/// A single category filter button with icon and label.
struct CategoryButton: View {
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
                            ? Color.taxiGold.opacity(0.15)
                            : Color.gray.opacity(0.12)
                    )
                    .clipShape(.rect(cornerRadius: 16))

                Text(category.label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isSelected ? Color.taxiGold : .primary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Places List

/// A list of nearby places, each tappable to select.
struct PlacesList: View {
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

// MARK: - Destination Banner

/// Banner showing the selected destination — tap the gold arrow to go directly there.
struct DestinationBanner: View {
    var destination: NearbyPlace
    var onGoDirectly: () -> Void
    var onClear: () -> Void

    var body: some View {
        Button {
            onGoDirectly()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.taxiGold)

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
                    .foregroundStyle(Color.taxiGold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.taxiGold.opacity(0.08))
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Row

/// A single place row with icon, name, address, and distance.
struct PlaceRow: View {
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
        .contentShape(.rect)
    }
}
