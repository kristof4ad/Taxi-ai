import SwiftUI

/// Sheet presented after a ride for the user to rate their experience, leave feedback, and tip.
struct RateRideView: View {
    @Bindable var viewModel: RateRideViewModel
    var onSubmit: (RideRating) -> Void
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RateRideCloseButton(onDismiss: onDismiss)

                RateRideHeader()

                StarRatingRow(rating: $viewModel.starRating)

                RateRideFeedbackArea(text: $viewModel.feedbackText)

                RateRideTipSection(viewModel: viewModel)

                RateRideSubmitButton(
                    canSubmit: viewModel.canSubmit,
                    onSubmit: { onSubmit(viewModel.buildRating()) }
                )
            }
        }
        .scrollIndicators(.hidden)
        .background(.background)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Close Button

/// X button to dismiss the rating sheet.
private struct RateRideCloseButton: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Button("Close", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(.rect(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Header

/// Subtitle and title for the rating screen.
private struct RateRideHeader: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("We care about your experience")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("How was your ride?")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Star Rating

/// Five interactive star buttons for selecting a rating.
private struct StarRatingRow: View {
    @Binding var rating: Int

    /// Amber gold color matching the Pencil design.
    private static let starColor = Color(red: 0.961, green: 0.620, blue: 0.043)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                Button {
                    rating = index
                } label: {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(index <= rating ? Self.starColor : .gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Feedback Text Area

/// Text editor for written feedback with a placeholder overlay.
private struct RateRideFeedbackArea: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.body)
                .padding(12)

            if text.isEmpty {
                Text("Share your feedback...")
                    .font(.body)
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 120)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Tip Section

/// "Leave a tip?" section with three percentage-based tip buttons.
private struct RateRideTipSection: View {
    @Bindable var viewModel: RateRideViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leave a tip?")
                .font(.title3.bold())

            HStack(spacing: 12) {
                ForEach(RateRideViewModel.tipPercentages, id: \.self) { percentage in
                    TipOptionButton(
                        percentage: percentage,
                        amount: viewModel.tipAmount(for: percentage),
                        currencyCode: viewModel.currencyCode,
                        isSelected: viewModel.selectedTipPercentage == percentage,
                        onTap: {
                            if viewModel.selectedTipPercentage == percentage {
                                viewModel.selectedTipPercentage = nil
                            } else {
                                viewModel.selectedTipPercentage = percentage
                            }
                        }
                    )
                }
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
    }
}

// MARK: - Tip Option Button

/// A single tip button showing the percentage and calculated amount.
private struct TipOptionButton: View {
    var percentage: Int
    var amount: Double
    var currencyCode: String
    var isSelected: Bool
    var onTap: () -> Void

    /// Gold highlight color for selected state.
    private static let goldColor = Color(red: 0.831, green: 0.659, blue: 0.294)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(percentage)%")
                    .font(.subheadline.weight(.semibold))

                Text(amount, format: .currency(code: currencyCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                isSelected ? Self.goldColor.opacity(0.1) : .clear,
                in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Self.goldColor : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Submit Button

/// Gold gradient submit button, disabled until at least one star is selected.
private struct RateRideSubmitButton: View {
    var canSubmit: Bool
    var onSubmit: () -> Void

    var body: some View {
        GoldButton(title: "Submit", action: onSubmit)
            .opacity(canSubmit ? 1 : 0.5)
            .disabled(!canSubmit)
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
    }
}
