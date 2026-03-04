import SwiftUI

/// Full-screen menu overlay with cancel and ride history options.
///
/// Displays a translucent background with a bottom card containing menu actions.
/// The cancel option label and visibility depend on the current ``RidePhase``.
struct AppMenuOverlay: View {
    @Binding var isPresented: Bool
    var ridePhase: RidePhase
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var showCancelConfirmation = false

    var body: some View {
        if isPresented {
            ZStack(alignment: .bottom) {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }

                // Menu card
                VStack(spacing: 0) {
                    if ridePhase != .none {
                        MenuRow(
                            title: ridePhase.cancelLabel,
                            icon: "xmark.circle",
                            role: .destructive
                        ) {
                            showCancelConfirmation = true
                        }

                        Divider()
                            .padding(.horizontal)
                    }

                    MenuRow(
                        title: "List of rides",
                        icon: "list.bullet"
                    ) {
                        withAnimation {
                            isPresented = false
                        }
                        onShowRideHistory()
                    }

                    Divider()
                        .padding(.horizontal)

                    MenuRow(
                        title: "Close",
                        icon: "chevron.down"
                    ) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
                .background(.background, in: .rect(cornerRadii: .init(topLeading: 20, topTrailing: 20)))
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
            }
            .transition(.opacity)
            .alert("Are you sure you want to cancel?", isPresented: $showCancelConfirmation) {
                Button("Yes, cancel", role: .destructive) {
                    withAnimation {
                        isPresented = false
                    }
                    onCancel()
                }

                Button("No", role: .cancel) { }
            }
        }
    }
}

// MARK: - Menu Row

/// A single tappable row inside the menu overlay.
private struct MenuRow: View {
    var title: String
    var icon: String
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)

                Text(title)
                    .font(.body)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
    }
}
