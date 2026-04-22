import Foundation

/// Internal setup errors for the voice transcription service. Converted to a
/// user-friendly message before being exposed as `VoiceTranscriptionState.unavailable`.
enum VoiceSetupError: Error {
    case simulatorUnsupported
    case micPermissionDenied
    case audioSessionBusy
    case audioSessionFailed(underlying: Error)
    case modelUnavailable
    case noCompatibleFormat
    case analyzerStartFailed
    case microphoneFailed

    var userMessage: String {
        switch self {
        case .simulatorUnsupported:
            "Voice search needs a physical iPhone — the iOS Simulator doesn't support on-device speech."
        case .micPermissionDenied:
            "Microphone access is required. Enable it in Settings to use voice search."
        case .audioSessionBusy:
            "Another app is using the microphone. Try again after ending any phone or voice calls."
        case .audioSessionFailed(let underlying):
            "Could not activate the microphone. \((underlying as NSError).localizedDescription)"
        case .modelUnavailable:
            "Voice search isn't available for your language or on this device yet."
        case .noCompatibleFormat:
            "No compatible audio format."
        case .analyzerStartFailed:
            "Could not start the transcriber."
        case .microphoneFailed:
            "Could not start the microphone."
        }
    }
}
