import SwiftUI

/// Reusable hamburger menu button used across all ride screens.
///
/// Toggles the bound `isPresented` state to show the app menu overlay.
struct AppMenuButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button("Menu", systemImage: "line.3.horizontal") {
            isPresented.toggle()
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .foregroundStyle(.primary)
        .frame(width: 40, height: 40)
        .background(.background, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
