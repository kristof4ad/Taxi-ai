import SwiftUI

/// Screen prompting the user to fasten their seatbelt before the ride begins.
/// Shows a seatbelt illustration with action buttons for trip management.
struct FastenSeatbeltsView: View {
    var viewModel: TripViewModel
    var onFastened: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FastenSeatbeltsHeader()

            SeatbeltIllustration()

            FastenSeatbeltsActions(onFastened: onFastened)
        }
        .background(.background)
    }
}

// MARK: - Header

/// Top section with menu button, subtitle, and title.
private struct FastenSeatbeltsHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            // Menu row
            HStack {
                Spacer()
                MenuButton()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Text section
            VStack(spacing: 4) {
                Text("To continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Fasten Seatbelts")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 8)
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

// MARK: - Seatbelt Illustration

/// Illustration of a car seat with a fastened seatbelt.
private struct SeatbeltIllustration: View {
    var body: some View {
        Image("SeatbeltIllustration")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
    }
}

// MARK: - Actions

/// Edit/Lock row and gold "Fastened" button.
private struct FastenSeatbeltsActions: View {
    var onFastened: () -> Void

    private static let goldStart = Color(red: 0.831, green: 0.659, blue: 0.294)
    private static let goldEnd = Color(red: 0.722, green: 0.581, blue: 0.290)

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionGridButton(title: "Edit Trip", icon: "pencil")
                ActionGridButton(title: "Lock", icon: "lock")
            }

            Button("Fastened", action: onFastened)
                .bold()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Self.goldStart, Self.goldEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(.rect(cornerRadius: 26))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Action Grid Button

private struct ActionGridButton: View {
    var title: String
    var icon: String?

    var body: some View {
        Button {
            // Action placeholder
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                }

                Text(title)
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.fill, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
