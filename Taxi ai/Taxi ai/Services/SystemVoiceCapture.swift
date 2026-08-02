@preconcurrency import AVFoundation
import Foundation
import OSLog
import Speech

private let log = Logger(subsystem: "com.ikristof.Taxi-ai", category: "VoiceCapture")

/// Live `VoiceCapturing`: records microphone audio to a temporary WAV file, then
/// transcribes that file via `SFSpeechURLRecognitionRequest`.
///
/// We tried the live-streaming path (both `SpeechAnalyzer` in iOS 26 and
/// `SFSpeechAudioBufferRecognitionRequest`) — both crash Apple's internal
/// `RealtimeMessenger.mServiceQueue` on some devices when audio buffers begin
/// flowing. File-based transcription flows through a different code path that
/// is stable and matches what proven apps like swift-scribe use.
@MainActor
final class SystemVoiceCapture: VoiceCapturing {
    private var audioRecorder: AVAudioRecorder?

    /// Held for the lifetime of a request: a deallocated recognizer drops its
    /// callback silently, stranding the caller.
    private var activeRecognizer: SFSpeechRecognizer?

    /// Aborts the in-flight transcription. Registered by the attempt that owns
    /// it and captured over that attempt's own handles, so invoking it can never
    /// cancel a newer attempt's work.
    private var cancelActiveRecognition: (() -> Void)?

    /// Distinguishes transcription attempts, so one finishing late cannot clear
    /// handles that now belong to a newer attempt.
    private var transcriptionGeneration = 0

    /// Upper bound on how long to wait for the recognizer before giving up.
    private static let transcriptionTimeout = Duration.seconds(30)

    // MARK: - Recording

    func startRecording() async throws -> URL {
        #if targetEnvironment(simulator)
        throw VoiceSetupError.simulatorUnsupported
        #else
        log.info("start: requesting mic permission")
        guard await requestMicrophonePermission() else {
            throw VoiceSetupError.micPermissionDenied
        }

        log.info("start: checking speech permission")
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw VoiceSetupError.micPermissionDenied
        }

        log.info("start: configuring audio session")
        do {
            try configureAudioSession()
        } catch {
            if audioSessionIsBusyWithCall(error) {
                throw VoiceSetupError.audioSessionBusy
            }
            throw VoiceSetupError.audioSessionFailed(underlying: error)
        }

        let url = FileManager.default.temporaryDirectory
            .appending(path: "voice-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder = recorder
            guard recorder.record() else {
                throw VoiceSetupError.microphoneFailed
            }
        } catch {
            // The recorder creates the file up front, so clear it before bailing
            // out — nobody else holds this URL once we throw.
            audioRecorder = nil
            discardRecording(at: url)
            log.error("start: recorder init failed \(error.localizedDescription, privacy: .public)")
            throw VoiceSetupError.microphoneFailed
        }

        log.info("start: recording to \(url.lastPathComponent, privacy: .public)")
        return url
        #endif
    }

    func stopRecording() {
        if let recorder = audioRecorder, recorder.isRecording { recorder.stop() }
        audioRecorder = nil
    }

    func discardRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Transcription

    func transcribe(fileAt url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current),
              recognizer.isAvailable else {
            throw VoiceSetupError.modelUnavailable
        }

        let generation = transcriptionGeneration

        // Hold the recognizer for the lifetime of the request — see `activeRecognizer`.
        activeRecognizer = recognizer

        // Held locally rather than on the instance: an attempt that finishes late
        // must not cancel or clear handles that now belong to a newer one.
        var watchdog: Task<Void, Never>?
        defer {
            watchdog?.cancel()
            // Only release shared state while this attempt still owns it.
            if generation == transcriptionGeneration {
                activeRecognizer = nil
                cancelActiveRecognition = nil
            }
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .search

        return try await withCheckedThrowingContinuation { continuation in
            let handoff = RecognitionContinuation(continuation)

            let recognition = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    handoff.finish(.failure(error))
                } else if let result, result.isFinal {
                    handoff.finish(.success(result.bestTranscription.formattedString))
                }
            }

            // Lets `cancelTranscription()` abort this attempt specifically.
            cancelActiveRecognition = {
                recognition.cancel()
                handoff.finish(.failure(CancellationError()))
            }

            // Bound the wait: if the framework never delivers a terminal
            // callback, this keeps the caller from hanging indefinitely.
            watchdog = Task {
                try? await Task.sleep(for: Self.transcriptionTimeout)
                guard !Task.isCancelled else { return }
                recognition.cancel()
                handoff.finish(.failure(VoiceSetupError.transcriptionTimedOut))
            }
        }
    }

    func cancelTranscription() {
        transcriptionGeneration += 1
        cancelActiveRecognition?()
        cancelActiveRecognition = nil
        activeRecognizer = nil
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Releases the `.record` session once recording is over, so playback-oriented
    /// audio — the vehicle sound effects — can take the shared session back.
    func releaseSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func audioSessionIsBusyWithCall(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSOSStatusErrorDomain && nsError.code == 560_030_580
    }

    // MARK: - Permissions

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default: return false
        }
    }
}
