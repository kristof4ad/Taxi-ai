import Testing

@testable import Taxi_ai

/// Covers the voice-search session state machine using a `VoiceCaptureStub`, so
/// the concurrency-sensitive rules — which late results still count, which stops
/// are duplicates — can be exercised without a microphone.
@MainActor
struct VoiceTranscriptionServiceTests {
    /// Yields until `condition` holds, so a test can wait for the service to park
    /// inside `transcribe` without sleeping for a fixed duration.
    private func waitUntil(
        _ condition: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var yields = 0
        while condition() == false, yields < 10_000 {
            await Task.yield()
            yields += 1
        }
        try #require(condition(), "Timed out waiting for the expected state.", sourceLocation: sourceLocation)
    }

    // MARK: - Initial state

    @Test func startsIdleWithNoTranscript() {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())

        #expect(service.state == .idle)
        #expect(service.volatileTranscript.isEmpty)
        #expect(service.finalizedTranscript.isEmpty)
        #expect(service.combinedTranscript.isEmpty)
    }

    // MARK: - combinedTranscript

    @Test func combinedTranscriptTrimsSurroundingWhitespace() {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())
        service.finalizedTranscript = "  take me to the airport \n"

        #expect(service.combinedTranscript == "take me to the airport")
    }

    /// Only finalized text is submitted to search; partial results are display-only.
    @Test func combinedTranscriptIgnoresVolatileText() {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())
        service.volatileTranscript = "take me to the air"
        service.finalizedTranscript = "take me to the airport"

        #expect(service.combinedTranscript == "take me to the airport")
    }

    // MARK: - start

    @Test func startBeginsRecording() async {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())

        await service.start()

        #expect(service.state == .recording)
    }

    @Test func startSurfacesSetupErrorMessage() async {
        let capture = VoiceCaptureStub()
        capture.startError = VoiceSetupError.micPermissionDenied
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()

        #expect(service.state == .unavailable(reason: VoiceSetupError.micPermissionDenied.userMessage))
    }

    @Test func startSurfacesAGenericMessageForUnexpectedErrors() async {
        struct UnexpectedFailure: Error {}
        let capture = VoiceCaptureStub()
        capture.startError = UnexpectedFailure()
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()

        #expect(service.state == .unavailable(reason: "Voice search couldn't start."))
    }

    @Test func startClearsTranscriptsFromAPreviousAttempt() async {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())
        service.finalizedTranscript = "stale text"

        await service.start()

        #expect(service.finalizedTranscript.isEmpty)
    }

    /// `start()` must no-op while a session is under way — the sheet's `task`
    /// modifier can fire again, and tearing down a live recording would lose speech.
    @Test(arguments: [
        VoiceTranscriptionState.preparing,
        .recording,
        .processing
    ])
    func startIsIgnoredWhileBusy(_ busyState: VoiceTranscriptionState) async {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())
        service.state = busyState

        await service.start()

        #expect(service.state == busyState, "start() should not disturb an active session.")
    }

    // MARK: - stop

    @Test func stopAppliesTheTranscriptAndFinishes() async {
        let capture = VoiceCaptureStub()
        capture.transcriptResult = .success("somewhere quiet to read")
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        await service.stop()

        #expect(service.state == .finished)
        #expect(service.combinedTranscript == "somewhere quiet to read")
    }

    @Test func stopReleasesTheSessionAndDeletesTheRecording() async {
        let capture = VoiceCaptureStub()
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        await service.stop()

        #expect(capture.discardedURLs.contains(capture.recordingURL))
        #expect(capture.releaseSessionCount >= 1)
    }

    @Test func failedTranscriptionStillFinishesWithoutText() async {
        let capture = VoiceCaptureStub()
        capture.transcriptResult = .failure(VoiceSetupError.modelUnavailable)
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        await service.stop()

        #expect(service.state == .finished)
        #expect(service.finalizedTranscript.isEmpty)
    }

    @Test func stopWithoutAnActiveRecordingFinishesImmediately() async {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())

        await service.stop()

        #expect(service.state == .finished)
    }

    /// A rapid second tap on Stop must not flip `.processing` to `.finished`,
    /// which would make the real transcript be rejected when it arrives.
    @Test(.timeLimit(.minutes(1))) func aDuplicateStopDoesNotDiscardTheTranscript() async throws {
        let capture = VoiceCaptureStub()
        capture.blocksUntilReleased = true
        capture.transcriptResult = .success("take me to the airport")
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        let stopping = Task { await service.stop() }
        try await waitUntil { capture.isTranscribing }

        await service.stop()
        #expect(service.state == .processing, "A duplicate stop must leave the in-flight one alone.")

        capture.releaseTranscription()
        await stopping.value

        #expect(service.state == .finished)
        #expect(service.combinedTranscript == "take me to the airport")
    }

    // MARK: - Session scoping

    /// Dismissing the sheet mid-transcription retires the session, so the
    /// abandoned result must not resurrect it from `.idle` back to `.finished`.
    @Test(.timeLimit(.minutes(1))) func aRetiredSessionDoesNotResurrectItself() async throws {
        let capture = VoiceCaptureStub()
        capture.blocksUntilReleased = true
        capture.transcriptResult = .success("stale transcript")
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        let stopping = Task { await service.stop() }
        try await waitUntil { capture.isTranscribing }
        #expect(service.state == .processing)

        service.reset()
        #expect(service.state == .idle)

        capture.releaseTranscription()
        await stopping.value

        #expect(service.state == .idle, "A retired session must not resurrect itself.")
        #expect(service.finalizedTranscript.isEmpty, "Its transcript must be discarded.")
    }

    /// The case the session generation exists for: an abandoned attempt lands its
    /// result while a *newer* session has already reached `.processing`. Without
    /// the generation check the stale transcript is accepted and the live session
    /// is marked finished — a state guard alone cannot tell the two apart.
    @Test(.timeLimit(.minutes(1))) func aRetiredSessionDoesNotClobberANewerOne() async throws {
        let capture = VoiceCaptureStub()
        capture.blocksUntilReleased = true
        // Keep the abandoned attempt in flight so the newer one can overtake it.
        capture.releasesOnCancel = false
        capture.transcriptResult = .success("stale transcript")
        let service = VoiceTranscriptionService(capture: capture)

        // Session A parks inside `transcribe`, then the user dismisses the sheet.
        await service.start()
        let stoppingA = Task { await service.stop() }
        try await waitUntil { capture.isTranscribing }
        service.reset()

        // Session B starts and reaches `.processing` while A is still parked.
        await service.start()
        let stoppingB = Task { await service.stop() }
        try await waitUntil { service.state == .processing }

        // A's stale result lands now.
        capture.releaseOldestTranscription()
        await stoppingA.value

        #expect(service.state == .processing, "A retired attempt must not finish the live session.")
        #expect(service.finalizedTranscript.isEmpty, "Its transcript must not be applied.")

        // Let B finish so the test leaves nothing running.
        capture.releaseTranscription()
        await stoppingB.value
        #expect(service.state == .finished)
    }

    /// The abandoned session must also leave the audio session alone — the newer
    /// recording owns it by then.
    @Test(.timeLimit(.minutes(1))) func aRetiredSessionDoesNotReleaseTheNewSessionsAudio() async throws {
        let capture = VoiceCaptureStub()
        capture.blocksUntilReleased = true
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        let stopping = Task { await service.stop() }
        try await waitUntil { capture.isTranscribing }

        service.reset()
        let releasesAfterReset = capture.releaseSessionCount

        capture.releaseTranscription()
        await stopping.value

        #expect(
            capture.releaseSessionCount == releasesAfterReset,
            "The retired session should not have released the audio session again."
        )
    }

    @Test(.timeLimit(.minutes(1))) func resetCancelsAnInFlightTranscription() async throws {
        let capture = VoiceCaptureStub()
        capture.blocksUntilReleased = true
        let service = VoiceTranscriptionService(capture: capture)

        await service.start()
        let stopping = Task { await service.stop() }
        try await waitUntil { capture.isTranscribing }

        service.reset()
        await stopping.value

        #expect(capture.cancelTranscriptionCount >= 1)
    }

    // MARK: - reset

    @Test func resetClearsTranscriptsAndReturnsToIdle() {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())
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
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())
        service.state = state

        service.reset()

        #expect(service.state == .idle)
    }

    /// Dismissing the sheet after stopping must leave the service reusable rather
    /// than stuck in `.finished`, which would break the next open.
    @Test func resetAfterStopReturnsServiceToIdle() async {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())

        await service.stop()
        service.reset()

        #expect(service.state == .idle)
    }

    @Test func startAfterResetRecordsAgain() async {
        let service = VoiceTranscriptionService(capture: VoiceCaptureStub())

        await service.start()
        service.reset()
        await service.start()

        #expect(service.state == .recording)
    }

    #if targetEnvironment(simulator)
    /// Confirms the default dependency really is the device implementation, which
    /// fails fast on the simulator rather than leaving the user on a spinner.
    @Test func defaultCaptureFailsFastOnSimulator() async {
        let service = VoiceTranscriptionService()

        await service.start()

        #expect(
            service.state == .unavailable(reason: VoiceSetupError.simulatorUnsupported.userMessage)
        )
    }
    #endif
}
