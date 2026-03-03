import SwiftUI

/// Black pill-shaped "Dropoff" label used as a map annotation.
struct DropoffMarkerView: View {
    var body: some View {
        Label("Dropoff", systemImage: "circle.fill")
            .labelStyle(.titleOnly)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black)
            .clipShape(.capsule)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}
