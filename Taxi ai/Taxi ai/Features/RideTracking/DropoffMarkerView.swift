import SwiftUI

/// Black pill-shaped label used as a map annotation for the destination.
struct DropoffMarkerView: View {
    var name: String = "Dropoff"

    var body: some View {
        Label(name, systemImage: "circle.fill")
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
