import SwiftUI

/// The initial welcome screen shown when the app launches.
struct WelcomeView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 120)

            LogoView()

            Spacer()

            BottomButtonSection(onTap: onGetStarted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Image(.backgroundToll2)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Logo

private struct LogoView: View {
    var body: some View {
        Text("Taxi ai")
            .font(.custom("ZenDots-Regular", size: 36))
            .tracking(4)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Bottom Button Section

private struct BottomButtonSection: View {
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            GoldButton(title: "Let's Go!", action: onTap)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }
}

// MARK: - Gold Button

struct GoldButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.83, green: 0.66, blue: 0.29),
                            Color(red: 0.72, green: 0.58, blue: 0.29)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
