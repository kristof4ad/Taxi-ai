import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.ikristof.Taxi-ai", category: "VoiceTranscription")

/// Drives the voice-search session: what state the sheet should show, and which
/// transcription results are still allowed to affect it.
///
/// All device work is delegated to a ``VoiceCapturing`` so this type stays
/// testable — see `SystemVoiceCapture` for the microphone and speech plumbing.
@MainActor
@Observable
final class VoiceTranscriptionService {
    // MARK: - Public state

    var state: VoiceTranscriptionState = .idle
    var volatileTranscript: String = ""
    var finalizedTranscript: String = ""

    var combinedTranscript: String {
        finalizedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private plumbing

    private let capture: any VoiceCapturing
    private var recordingURL: URL?

    /// Identifies the current recording session. Bumped whenever a session is
    /// abandoned so late work from an earlier one can be told apart from the
    /// session that replaced it.
    private var sessionGeneration = 0

    init(capture: any VoiceCapturing = SystemVoiceCapture()) {
        self.capture = capture
    }

    // MARK: - Public API

    /// Requests permission, prepares the recorder, and starts recording.
    func start() async {
        guard state != .recording, state != .preparing, state != .processing else { return }
        reset()
        state = .preparing

        do {
            recordingURL = try await capture.startRecording()
            state = .recording
        } catch let error as VoiceSetupError {
            state = .unavailable(reason: error.userMessage)
        } catch {
            state = .unavailable(reason: "Voice search couldn't start.")
        }
    }

    /// Stops recording and transcribes the captured audio file.
    func stop() async {
        // A repeat tap while the first call is still transcribing must not touch
        // state: flipping `.processing` to `.finished` here would make the real
        // transcript be rejected when it finally arrives.
        guard state != .processing else { return }

        guard let url = recordingURL else {
            state = .finished
            return
        }

        capture.stopRecording()
        state = .processing
        let generation = sessionGeneration
        log.info("stop: recording ended, transcribing \(url.lastPathComponent, privacy: .public)")

        var transcript: String?
        do {
            transcript = try await capture.transcribe(fileAt: url)
            log.info("stop: transcription chars=\(transcript?.count ?? 0)")
        } catch {
            log.error("stop: transcription failed \(error.localizedDescription, privacy: .public)")
        }

        // This recording's own temp file, so it is always safe to remove.
        capture.discardRecording(at: url)

        // A newer session started while this transcription was in flight — for
        // example the user swiped the sheet away and tried again. Leave its
        // audio session and state alone; this result belongs to nobody.
        guard generation == sessionGeneration else { return }

        recordingURL = nil
        capture.releaseSession()

        guard state == .processing else { return }
        if let transcript { finalizedTranscript = transcript }
        state = .finished
    }

    /// Clears transcripts and returns to `.idle`.
    ///
    /// Also retires the current session, so a transcription still in flight
    /// cannot come back and clobber whatever starts next.
    func reset() {
        sessionGeneration += 1
        capture.stopRecording()
        capture.cancelTranscription()
        if let url = recordingURL { capture.discardRecording(at: url) }
        recordingURL = nil
        volatileTranscript = ""
        finalizedTranscript = ""
        state = .idle
        capture.releaseSession()
    }
}
