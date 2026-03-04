import SwiftUI

// MARK: - White Flash Overlay

/// Phases for a brief white screen flash (simulating headlights blinking).
enum HeadlightFlashPhase: CaseIterable {
    case idle
    case bright
    case fadeOut

    var opacity: Double {
        switch self {
        case .idle: 0
        case .bright: 1
        case .fadeOut: 0
        }
    }
}

/// Full-screen white flash that simulates car headlights blinking.
struct HeadlightFlashOverlay: View {
    /// Increment this value to trigger a flash.
    var trigger: Int

    var body: some View {
        Color.white
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .phaseAnimator(HeadlightFlashPhase.allCases, trigger: trigger) { content, phase in
                content.opacity(phase.opacity)
            } animation: { phase in
                switch phase {
                case .idle: .easeOut(duration: 0.3)
                case .bright: .easeIn(duration: 0.05)
                case .fadeOut: .easeOut(duration: 0.3)
                }
            }
    }
}

// MARK: - Hazard Blink Overlay

/// Phases for the hazard blinker: three on/off pulses.
enum HazardBlinkPhase: CaseIterable {
    case off1, on1, off2, on2, off3, on3, done

    var opacity: Double {
        switch self {
        case .off1, .off2, .off3, .done: 0
        case .on1, .on2, .on3: 1
        }
    }
}

/// Overlay that flashes orange gradients at the four corners of the screen three times,
/// simulating car hazard/blinker lights.
struct HazardBlinkOverlay: View {
    /// Increment this value to trigger three blinks.
    var trigger: Int

    /// The orange color used for the hazard glow.
    private static let hazardOrange = Color(red: 0.83, green: 0.66, blue: 0.29)

    var body: some View {
        ZStack {
            CornerGlow(center: .topLeading)
            CornerGlow(center: .topTrailing)
            CornerGlow(center: .bottomLeading)
            CornerGlow(center: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .phaseAnimator(HazardBlinkPhase.allCases, trigger: trigger) { content, phase in
            content.opacity(phase.opacity)
        } animation: { phase in
            switch phase {
            case .on1, .on2, .on3:
                .easeIn(duration: 0.1)
            case .off1, .off2, .off3:
                .easeOut(duration: 0.15)
            case .done:
                .easeOut(duration: 0.2)
            }
        }
    }
}

// MARK: - Corner Glow

/// A radial gradient glow anchored to a specific corner of the screen.
private struct CornerGlow: View {
    var center: UnitPoint

    /// The orange color used for the hazard glow.
    private static let hazardOrange = Color(red: 0.83, green: 0.66, blue: 0.29)

    var body: some View {
        RadialGradient(
            colors: [
                Self.hazardOrange.opacity(0.8),
                Self.hazardOrange.opacity(0.3),
                .clear
            ],
            center: center,
            startRadius: 0,
            endRadius: 250
        )
    }
}
