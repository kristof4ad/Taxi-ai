import SwiftUI

/// Overlay that flashes amber gradients at the four corners of the screen,
/// simulating car hazard lights.
struct HazardBlinkOverlay: View {
    /// Increment this value to trigger the blink.
    var trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CornerGlow(center: .topLeading)
            CornerGlow(center: .topTrailing)
            CornerGlow(center: .bottomLeading)
            CornerGlow(center: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .phaseAnimator(
            FlashPhase.sequence(reduceMotion: reduceMotion),
            trigger: trigger
        ) { content, phase in
            content.opacity(phase.opacity * FlashPhase.peakOpacity(reduceMotion: reduceMotion))
        } animation: { phase in
            phase.animation(reduceMotion: reduceMotion)
        }
    }
}
