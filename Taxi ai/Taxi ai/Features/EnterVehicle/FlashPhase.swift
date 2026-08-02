import SwiftUI

/// Phases for the vehicle light effects: three on/off pulses that mimic
/// headlights or hazard blinkers.
enum FlashPhase: CaseIterable {
    case off1, on1, off2, on2, off3, on3, done

    /// The phase sequence to animate through.
    ///
    /// Repeated full-screen flashing is uncomfortable, and for photosensitive
    /// riders it is a genuine hazard, so Reduce Motion collapses the effect to a
    /// single gentle pulse.
    static func sequence(reduceMotion: Bool) -> [FlashPhase] {
        reduceMotion ? [.off1, .on1, .done] : allCases
    }

    /// Relative brightness of this phase, before the peak opacity is applied.
    var opacity: Double {
        switch self {
        case .off1, .off2, .off3, .done: 0
        case .on1, .on2, .on3: 1
        }
    }

    /// The animation used when transitioning into this phase.
    func animation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            .easeInOut(duration: 0.45)
        } else {
            switch self {
            case .on1, .on2, .on3: .easeIn(duration: 0.1)
            case .off1, .off2, .off3: .easeOut(duration: 0.15)
            case .done: .easeOut(duration: 0.2)
            }
        }
    }

    /// Peak opacity for the effect. Reduce Motion gets a soft glow rather than a
    /// full-brightness blast.
    static func peakOpacity(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.35 : 1
    }
}
