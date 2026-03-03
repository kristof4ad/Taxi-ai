import SwiftUI

/// White pill-shaped "Pickup" label used as a map annotation.
struct PickupMarkerView: View {
    var body: some View {
        Label("Pickup", systemImage: "circle")
            .labelStyle(.titleOnly)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.background)
            .clipShape(.capsule)
            .overlay {
                Capsule().stroke(Color(.systemGray4), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
