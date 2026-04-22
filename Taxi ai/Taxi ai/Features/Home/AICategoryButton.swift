import SwiftUI

/// A category-row pill that opens the voice-search sheet instead of filtering POIs.
struct AICategoryButton: View {
    var action: () -> Void

    private static let gold = Color(red: 0.83, green: 0.66, blue: 0.29)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [Self.gold, Self.gold.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: .rect(cornerRadius: 16)
                    )

                Text("AI")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Self.gold)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI voice search")
    }
}
