import SwiftUI

// These are immutable `Sendable` constants, so they are marked `nonisolated` to
// stay readable from any context despite the module's MainActor default isolation.

extension Color {
    /// The app's primary brand gold, used for calls to action and highlights.
    nonisolated static let taxiGold = Color(red: 0.83, green: 0.66, blue: 0.29)

    /// The darker gold that ends the brand gradient.
    nonisolated static let taxiGoldDark = Color(red: 0.72, green: 0.58, blue: 0.29)

    /// Amber used to fill rating stars. Deliberately warmer than the brand gold
    /// so a filled star reads as a rating rather than as a tappable control.
    nonisolated static let ratingAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
}

extension LinearGradient {
    /// The vertical brand gradient used on primary buttons.
    nonisolated static let taxiGold = LinearGradient(
        colors: [.taxiGold, .taxiGoldDark],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The horizontal brand gradient, used on wide buttons and banners.
    nonisolated static let taxiGoldHorizontal = LinearGradient(
        colors: [.taxiGold, .taxiGoldDark],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// The pressed state of the vertical brand gradient.
    nonisolated static let taxiGoldPressed = LinearGradient(
        colors: [
            Color(red: 0.66, green: 0.53, blue: 0.23),
            Color(red: 0.58, green: 0.46, blue: 0.23)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
