import SwiftUI

/// A category-row pill that opens the voice-search sheet instead of filtering POIs.
struct AICategoryButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color.taxiGold, Color.taxiGold.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: .rect(cornerRadius: 16)
                    )

                Text("AI")
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Color.taxiGold)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI voice search")
    }
}
