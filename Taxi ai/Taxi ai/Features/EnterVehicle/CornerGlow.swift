import SwiftUI

/// A radial gradient glow anchored to a specific corner of the screen.
struct CornerGlow: View {
    var center: UnitPoint

    var body: some View {
        RadialGradient(
            colors: [
                .taxiGold.opacity(0.8),
                .taxiGold.opacity(0.3),
                .clear
            ],
            center: center,
            startRadius: 0,
            endRadius: 250
        )
    }
}
