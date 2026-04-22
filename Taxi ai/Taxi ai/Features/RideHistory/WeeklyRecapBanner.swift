import SwiftUI

/// Banner shown at the top of Ride History with an AI-generated recap of
/// the rides in the past 7 days. Hidden entirely when no recap is available.
struct WeeklyRecapBanner: View {
    let recap: RideRecap

    private static let gold = Color(red: 0.83, green: 0.66, blue: 0.29)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("This week")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Self.gold)

            Text(recap.headline)
                .font(.headline)

            Text(recap.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.gold.opacity(0.08), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
