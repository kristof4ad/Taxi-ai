import Foundation

@testable import Taxi_ai

/// A `VoiceCapturing` double that lets tests drive recording and transcription
/// timing by hand, including parking inside `transcribe` so a session can be
/// abandoned or stopped again while a result is still in flight.
@MainActor
final class VoiceCaptureStub: VoiceCapturing {
    /// The URL handed back from `startRecording()`.
    var recordingURL = URL(filePath: "/tmp/voice-capture-stub.wav")

    /// When set, `startRecording()` throws this instead of succeeding.
    var startError: (any Error)?

    /// The outcome `transcribe(fileAt:)` produces once it is allowed to finish.
    var transcriptResult: Result<String, any Error> = .success("take me to the airport")

    /// When true, `transcribe(fileAt:)` blocks until the test releases it.
    var blocksUntilReleased = false

    /// Whether `cancelTranscription()` also resumes parked callers, as the real
    /// implementation does. Tests that need an abandoned attempt to stay in
    /// flight — so a newer session can overtake it — set this to false.
    var releasesOnCancel = true

    /// True while a `transcribe(fileAt:)` call is parked or running.
    private(set) var isTranscribing = false

    private(set) var stopRecordingCount = 0
    private(set) var cancelTranscriptionCount = 0
    private(set) var releaseSessionCount = 0
    private(set) var discardedURLs: [URL] = []

    /// Parked `transcribe` callers. Held as a list rather than a single slot so a
    /// regression that starts a second transcription cannot deadlock the test —
    /// every parked caller is resumed, letting the assertion fail instead.
    private var gates: [CheckedContinuation<Void, Never>] = []

    // MARK: - VoiceCapturing

    func startRecording() async throws -> URL {
        if let startError { throw startError }
        return recordingURL
    }

    func stopRecording() {
        stopRecordingCount += 1
    }

    func transcribe(fileAt url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }

        if blocksUntilReleased {
            await withCheckedContinuation { gates.append($0) }
        }
        return try transcriptResult.get()
    }

    func cancelTranscription() {
        cancelTranscriptionCount += 1
        // The real implementation resumes its caller promptly on cancel.
        if releasesOnCancel { releaseTranscription() }
    }

    func discardRecording(at url: URL) {
        discardedURLs.append(url)
    }

    func releaseSession() {
        releaseSessionCount += 1
    }

    // MARK: - Test control

    /// Lets every parked `transcribe(fileAt:)` call proceed to its result.
    func releaseTranscription() {
        let parked = gates
        gates = []
        for gate in parked { gate.resume() }
    }

    /// Lets only the longest-parked `transcribe(fileAt:)` call proceed, so a test
    /// can land an older attempt's result while a newer one is still in flight.
    func releaseOldestTranscription() {
        guard gates.isEmpty == false else { return }
        gates.removeFirst().resume()
    }
}
