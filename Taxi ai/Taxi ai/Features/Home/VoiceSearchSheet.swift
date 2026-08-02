import SwiftUI

/// Sheet presented when the user taps the AI category pill. Records on-device,
/// shows a live transcript, and hands the final text back via `onSubmit`.
struct VoiceSearchSheet: View {
    @Bindable var service: VoiceTranscriptionService
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VoiceSearchHeader(state: service.state, onDismiss: onDismiss)

            Spacer()

            VoiceSearchBody(
                state: service.state,
                liveText: service.volatileTranscript,
                finalText: service.finalizedTranscript
            )

            Spacer()

            VoiceSearchActions(
                state: service.state,
                finalText: service.combinedTranscript,
                onStart: { await service.start() },
                onStop: { await service.stop() },
                onRetry: {
                    service.reset()
                    await service.start()
                },
                onSubmit: { onSubmit(service.combinedTranscript) }
            )
        }
        .padding(24)
        .task {
            if service.state == .idle {
                await service.start()
            }
        }
    }
}

// MARK: - Header

private struct VoiceSearchHeader: View {
    let state: VoiceTranscriptionState
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Button("Close", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch state {
        case .idle, .preparing: "Voice search"
        case .recording: "Listening…"
        case .processing: "Transcribing…"
        case .finished: "Did we get it right?"
        case .unavailable: "Voice search unavailable"
        }
    }
}

// MARK: - Body

private struct VoiceSearchBody: View {
    let state: VoiceTranscriptionState
    let liveText: String
    let finalText: String

    var body: some View {
        switch state {
        case .idle, .preparing:
            VoiceSearchIdleView()
        case .recording:
            VoiceSearchRecordingView(liveText: liveText, finalText: finalText)
        case .processing:
            VoiceSearchProcessingView()
        case .finished:
            VoiceSearchTranscriptView(text: finalText.isEmpty ? liveText : finalText)
        case .unavailable(let reason):
            VoiceSearchUnavailableView(reason: reason)
        }
    }
}

// MARK: - States

private struct VoiceSearchIdleView: View {

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.taxiGold)
            Text("Preparing microphone…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct VoiceSearchRecordingView: View {
    let liveText: String
    let finalText: String

    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.taxiGold.opacity(pulse ? 0.25 : 0.08))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.taxiGold)
                    .frame(width: 88, height: 88)

                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
            .onAppear { pulse = true }

            Text(displayText.isEmpty ? "Speak now…" : displayText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(displayText.isEmpty ? .secondary : .primary)
                .padding(.horizontal)
                .frame(minHeight: 64)
        }
    }

    private var displayText: String {
        (finalText + liveText).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct VoiceSearchProcessingView: View {

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.taxiGold)
            Text("Transcribing your request…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct VoiceSearchTranscriptView: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(text.isEmpty ? "We didn't catch that." : text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

private struct VoiceSearchUnavailableView: View {
    let reason: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(reason)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Actions

private struct VoiceSearchActions: View {
    let state: VoiceTranscriptionState
    let finalText: String
    var onStart: () async -> Void
    var onStop: () async -> Void
    var onRetry: () async -> Void
    var onSubmit: () -> Void

    var body: some View {
        switch state {
        case .idle, .preparing, .processing:
            EmptyView()

        case .recording:
            Button {
                Task { await onStop() }
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.taxiGold, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

        case .finished:
            HStack(spacing: 12) {
                Button {
                    Task { await onRetry() }
                } label: {
                    Text("Try again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.gray.opacity(0.12), in: .rect(cornerRadius: 14))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(action: onSubmit) {
                    Text("Search")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.taxiGold, in: .rect(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(finalText.isEmpty)
                .opacity(finalText.isEmpty ? 0.5 : 1)
            }

        case .unavailable:
            EmptyView()
        }
    }
}
