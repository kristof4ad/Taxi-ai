@preconcurrency import AVFoundation
import Foundation
import OSLog
import Speech
import SwiftUI

private let log = Logger(subsystem: "com.ikristof.Taxi-ai", category: "VoiceTranscription")

/// On-device voice transcription. Records microphone audio to a temporary WAV
/// file, then transcribes the file via `SFSpeechURLRecognitionRequest`.
///
/// We tried the live-streaming path (both `SpeechAnalyzer` in iOS 26 and
/// `SFSpeechAudioBufferRecognitionRequest`) — both crash Apple's internal
/// `RealtimeMessenger.mServiceQueue` on some devices when audio buffers begin
/// flowing. File-based transcription flows through a different code path that
/// is stable and matches what proven apps like swift-scribe use.
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

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    /// Held for the lifetime of a request: a deallocated recognizer drops its
    /// callback silently, stranding the caller.
    private var activeRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var transcriptionWatchdog: Task<Void, Never>?

    /// Upper bound on how long to wait for the recognizer before giving up.
    private static let transcriptionTimeout = Duration.seconds(30)

    // MARK: - Public API

    /// Requests permission, prepares the recorder, and starts recording.
    func start() async {
        guard state != .recording, state != .preparing, state != .processing else { return }
        reset()
        state = .preparing

        do {
            try await prepareAndStartRecording()
            state = .recording
        } catch let error as VoiceSetupError {
            state = .unavailable(reason: error.userMessage)
        } catch {
            state = .unavailable(reason: "Voice search couldn't start.")
        }
    }

    /// Stops recording and transcribes the captured audio file.
    func stop() async {
        guard let recorder = audioRecorder, let url = recordingURL else {
            state = .finished
            return
        }

        if recorder.isRecording { recorder.stop() }
        audioRecorder = nil
        state = .processing
        log.info("stop: recording ended, transcribing \(url.lastPathComponent, privacy: .public)")

        var transcript: String?
        do {
            transcript = try await transcribeFile(at: url)
            log.info("stop: transcription chars=\(transcript?.count ?? 0)")
        } catch {
            log.error("stop: transcription failed \(error.localizedDescription, privacy: .public)")
        }

        // Delete the temp file — we don't need to keep it.
        try? FileManager.default.removeItem(at: url)
        if recordingURL == url { recordingURL = nil }

        // `reset()` may have run while transcription was in flight — for example
        // the user swiped the sheet away. Don't resurrect a finished session.
        guard state == .processing else { return }
        if let transcript { finalizedTranscript = transcript }
        state = .finished
    }

    /// Clears transcripts and returns to `.idle`.
    func reset() {
        if let recorder = audioRecorder, recorder.isRecording { recorder.stop() }
        audioRecorder = nil
        cancelRecognitionTask()
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        volatileTranscript = ""
        finalizedTranscript = ""
        state = .idle
    }

    // MARK: - Recording

    private func prepareAndStartRecording() async throws {
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
        recordingURL = url

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
        } catch is VoiceSetupError {
            throw VoiceSetupError.microphoneFailed
        } catch {
            log.error("start: recorder init failed \(error.localizedDescription, privacy: .public)")
            throw VoiceSetupError.microphoneFailed
        }
        log.info("start: recording to \(url.lastPathComponent, privacy: .public)")
        #endif
    }

    // MARK: - File-based transcription

    private func transcribeFile(at url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current),
              recognizer.isAvailable else {
            throw VoiceSetupError.modelUnavailable
        }

        // Hold the recognizer for the lifetime of the request — see `activeRecognizer`.
        activeRecognizer = recognizer
        defer {
            activeRecognizer = nil
            recognitionTask = nil
            transcriptionWatchdog?.cancel()
            transcriptionWatchdog = nil
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .search

        return try await withCheckedThrowingContinuation { continuation in
            let handoff = RecognitionContinuation(continuation)

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    handoff.finish(.failure(error))
                } else if let result, result.isFinal {
                    handoff.finish(.success(result.bestTranscription.formattedString))
                }
            }

            // Bound the wait: if the framework never delivers a terminal
            // callback, this keeps the caller from hanging indefinitely.
            transcriptionWatchdog = Task {
                try? await Task.sleep(for: Self.transcriptionTimeout)
                guard !Task.isCancelled else { return }
                self.cancelRecognitionTask()
                handoff.finish(.failure(VoiceSetupError.transcriptionTimedOut))
            }
        }
    }

    /// Cancels any in-flight speech recognition task.
    private func cancelRecognitionTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
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
