import SwiftUI

/// Full-screen white flash that simulates car headlights blinking.
struct HeadlightFlashOverlay: View {
    /// Increment this value to trigger the flash.
    var trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.white
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
