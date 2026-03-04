import SwiftUI

/// A top-down car image used as a map annotation that rotates to face
/// the direction of travel, with an optional "Pickup" label shown below.
struct CarMarkerView: View {
    /// Whether to display the "Pickup" label beneath the car icon.
    var showPickupLabel = false

    /// Target bearing in degrees (0 = north, 90 = east).
    var bearing: Double = 0

    /// Rotation offset to correct for the car image's default orientation.
    private static let imageRotationOffset: Double = 0

    /// Cumulative rotation — not clamped to 0–360 so SwiftUI animations
    /// always interpolate via the shortest arc, never spinning the long way.
    @State private var displayRotation: Double = 0

    /// The last normalized target used to compute shortest-path deltas.
    @State private var previousTarget: Double = 0

    /// Whether the initial bearing has been captured (skip animation on first value).
    @State private var isInitialized = false

    var body: some View {
        VStack(spacing: 2) {
            Image("CarMapIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(displayRotation))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            if showPickupLabel {
                Text("Pickup")
                    .font(.caption2)
                    .bold()
            }
        }
        .onChange(of: bearing) { _, newBearing in
            let corrected = newBearing + Self.imageRotationOffset

            guard isInitialized else {
                displayRotation = corrected
                previousTarget = corrected
                isInitialized = true
                return
            }

            // Compute shortest-path delta across the 360°/0° boundary.
            var delta = corrected - previousTarget
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            previousTarget = corrected

            // Suppress sub-degree jitter.
            guard abs(delta) > 1 else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                displayRotation += delta
            }
        }
    }
}
