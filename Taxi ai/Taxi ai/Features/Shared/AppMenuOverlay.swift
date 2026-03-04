import SwiftUI

/// Floating dropdown menu that appears below the hamburger button.
///
/// Displays menu actions anchored to the top-trailing corner.
/// The cancel option label and visibility depend on the current ``RidePhase``.
struct AppMenuOverlay: View {
    @Binding var isPresented: Bool
    var ridePhase: RidePhase
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var showCancelConfirmation = false

    var body: some View {
        if isPresented {
            ZStack(alignment: .topTrailing) {
                // Transparent tap catcher to dismiss on tap outside
                Color.clear
                    .contentShape(.rect)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }

                // Floating menu card
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
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                        onShowRideHistory()
                    }
                }
                .background(.background, in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.top, 62)
                .padding(.trailing, 16)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            .alert("Cancel the ride", isPresented: $showCancelConfirmation) {
                Button("Yes, cancel", role: .destructive) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                    onCancel()
                }

                Button("No", role: .cancel) { }
            } message: {
                Text(ridePhase.cancelMessage)
            }
        }
    }
}

// MARK: - Menu Row

/// A single tappable row inside the floating menu.
private struct MenuRow: View {
    var title: String
    var icon: String
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
