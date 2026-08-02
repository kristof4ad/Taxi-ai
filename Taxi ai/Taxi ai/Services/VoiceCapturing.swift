import Foundation

/// The device-facing half of voice search: microphone capture and speech
/// recognition.
///
/// Split out from `VoiceTranscriptionService` so that the service holds only the
/// session state machine. That machine has the subtle rules — which results are
/// still current, which stops are duplicates — and this seam is what lets them
/// be tested without a microphone.
@MainActor
protocol VoiceCapturing {
    /// Starts recording and returns the file being written to.
    func startRecording() async throws -> URL

    /// Stops an in-progress recording, leaving its file on disk.
    func stopRecording()

    /// Transcribes a previously recorded file.
    func transcribe(fileAt url: URL) async throws -> String

    /// Aborts an in-flight transcription, resuming its caller promptly.
    func cancelTranscription()

    /// Deletes a recording that is no longer needed.
    func discardRecording(at url: URL)

    /// Releases the shared audio session so other audio can claim it.
    func releaseSession()
}
