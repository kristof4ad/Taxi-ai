import Testing

@testable import Taxi_ai

/// Covers the parts of `VoiceTranscriptionService` that are reachable without a
/// microphone: its published state, the transcript accessors, and the lifecycle
/// guards that decide whether `start()`/`stop()` do anything at all.
///
/// The transcription path itself (and therefore the `sessionGeneration` scoping
/// that keeps an abandoned attempt from clobbering a newer one) is *not* covered
/// here — driving it needs a real recorder, so testing it would first require
/// injecting a seam for `transcribeFile(at:)`.
@MainActor
struct VoiceTranscriptionServiceTests {
    // MARK: - Initial state

    @Test func startsIdleWithNoTranscript() {
        let service = VoiceTranscriptionService()

        #expect(service.state == .idle)
        #expect(service.volatileTranscript.isEmpty)
        #expect(service.finalizedTranscript.isEmpty)
        #expect(service.combinedTranscript.isEmpty)
    }

    // MARK: - combinedTranscript

    @Test func combinedTranscriptTrimsSurroundingWhitespace() {
        let service = VoiceTranscriptionService()
        service.finalizedTranscript = "  take me to the airport \n"

        #expect(service.combinedTranscript == "take me to the airport")
    }

    /// Only finalized text is submitted to search; partial results are display-only.
    @Test func combinedTranscriptIgnoresVolatileText() {
        let service = VoiceTranscriptionService()
        service.volatileTranscript = "take me to the air"
        service.finalizedTranscript = "take me to the airport"

        #expect(service.combinedTranscript == "take me to the airport")
    }

    // MARK: - reset

    @Test func resetClearsTranscriptsAndReturnsToIdle() {
        let service = VoiceTranscriptionService()
        service.volatileTranscript = "partial"
        service.finalizedTranscript = "final"
        service.state = .finished

        service.reset()

        #expect(service.state == .idle)
        #expect(service.volatileTranscript.isEmpty)
        #expect(service.finalizedTranscript.isEmpty)
    }

    @Test(arguments: [
        VoiceTranscriptionState.preparing,
        .recording,
        .processing,
        .finished,
        .unavailable(reason: "Microphone unavailable.")
    ])
    func resetReturnsToIdleFromAnyState(_ state: VoiceTranscriptionState) {
        let service = VoiceTranscriptionService()
        service.state = state

        service.reset()

        #expect(service.state == .idle)
    }

    @Test func resetIsSafeToCallRepeatedly() {
        let service = VoiceTranscriptionService()

        service.reset()
        service.reset()

        #expect(service.state == .idle)
    }

    // MARK: - start guards

    /// `start()` must no-op while a session is already under way — the sheet's
    /// `task` modifier can fire again, and tearing down a live recording (or
    /// stranding an in-flight transcription) would lose the user's speech.
    @Test(arguments: [
        VoiceTranscriptionState.preparing,
        .recording,
        .processing
    ])
    func startIsIgnoredWhileBusy(_ busyState: VoiceTranscriptionState) async {
        let service = VoiceTranscriptionService()
        service.state = busyState

        await service.start()

        #expect(service.state == busyState, "start() should not disturb an active session.")
    }

    // MARK: - stop

    @Test func stopWithoutAnActiveRecordingFinishesImmediately() async {
        let service = VoiceTranscriptionService()

        await service.stop()

        #expect(service.state == .finished)
    }

    @Test func stopIsSafeToCallTwice() async {
        let service = VoiceTranscriptionService()

        await service.stop()
        await service.stop()

        #expect(service.state == .finished)
    }

    /// Dismissing the sheet after stopping must leave the service reusable rather
    /// than stuck in `.finished`, which would break the next open.
    @Test func resetAfterStopReturnsServiceToIdle() async {
        let service = VoiceTranscriptionService()

        await service.stop()
        service.reset()

        #expect(service.state == .idle)
    }

    #if targetEnvironment(simulator)
    /// The simulator has no usable microphone, so setup fails fast with a message
    /// the sheet can show instead of leaving the user on a spinner forever.
    @Test func startSurfacesSimulatorUnsupported() async {
        let service = VoiceTranscriptionService()

        await service.start()

        #expect(
            service.state == .unavailable(reason: VoiceSetupError.simulatorUnsupported.userMessage)
        )
    }

    @Test func startFailureLeavesTranscriptsEmpty() async {
        let service = VoiceTranscriptionService()
        service.finalizedTranscript = "stale text from a previous attempt"

        await service.start()

        #expect(service.finalizedTranscript.isEmpty, "start() resets before attempting setup.")
    }
    #endif
}
