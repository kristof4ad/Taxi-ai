import Testing

@testable import Taxi_ai

/// `RecognitionContinuation` exists to guarantee a checked continuation resumes
/// exactly once, no matter how the recognizer callback, the watchdog timeout and
/// `reset()` interleave.
///
/// Note the failure mode: a *second* resume traps inside `CheckedContinuation`,
/// so a regression crashes these tests rather than failing them politely. Simply
/// reaching an expectation therefore proves the guarantee held.
struct RecognitionContinuationTests {
    // MARK: - Single outcome

    @Test func resumesWithTheFirstSuccess() async throws {
        let value = try await withCheckedThrowingContinuation { continuation in
            let handoff = RecognitionContinuation(continuation)
            handoff.finish(.success("take me to the airport"))
        }

        #expect(value == "take me to the airport")
    }

    @Test func propagatesTheFirstFailure() async {
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                let handoff = RecognitionContinuation(continuation)
                handoff.finish(.failure(VoiceSetupError.transcriptionTimedOut))
            }
            Issue.record("Expected the failure to propagate.")
        } catch VoiceSetupError.transcriptionTimedOut {
            // Expected.
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    // MARK: - Later outcomes are dropped

    /// The recognizer can report a result *and* an error; whichever lands first wins.
    @Test func laterSuccessesAreDropped() async throws {
        let value = try await withCheckedThrowingContinuation { continuation in
            let handoff = RecognitionContinuation(continuation)
            handoff.finish(.success("first"))
            handoff.finish(.success("second"))
            handoff.finish(.failure(VoiceSetupError.transcriptionTimedOut))
        }

        #expect(value == "first")
    }

    /// The watchdog firing after a real failure must not resume a second time.
    @Test func laterFailuresAreDropped() async {
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                let handoff = RecognitionContinuation(continuation)
                handoff.finish(.failure(VoiceSetupError.modelUnavailable))
                handoff.finish(.failure(VoiceSetupError.transcriptionTimedOut))
                handoff.finish(.success("late transcript"))
            }
            Issue.record("Expected the first failure to propagate.")
        } catch VoiceSetupError.modelUnavailable {
            // Expected — the first outcome wins.
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    // MARK: - Contention

    /// Models the real race: the recognizer callback, the watchdog and `reset()`
    /// can all reach `finish` from different executors at the same moment.
    @Test func concurrentFinishesStillResumeExactlyOnce() async {
        let outcome: Result<String, any Error>
        do {
            let value = try await withCheckedThrowingContinuation { continuation in
                let handoff = RecognitionContinuation(continuation)
                for index in 0..<64 {
                    Task.detached {
                        if index.isMultiple(of: 2) {
                            handoff.finish(.success("racer-\(index)"))
                        } else {
                            handoff.finish(.failure(VoiceSetupError.transcriptionTimedOut))
                        }
                    }
                }
            }
            outcome = .success(value)
        } catch {
            outcome = .failure(error)
        }

        // Getting here means exactly one racer won — a second resume would have trapped.
        switch outcome {
        case .success(let value):
            #expect(value.hasPrefix("racer-"), "A success should carry its racer's value.")
        case .failure(let error):
            #expect(error is VoiceSetupError, "A failure should carry the racer's error.")
        }
    }
}
