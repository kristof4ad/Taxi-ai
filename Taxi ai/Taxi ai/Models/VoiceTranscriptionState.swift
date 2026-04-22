/// Lifecycle states for the voice-search transcription flow.
enum VoiceTranscriptionState: Equatable, Sendable {
    case idle
    case preparing
    case recording
    case processing
    case finished
    case unavailable(reason: String)
}
