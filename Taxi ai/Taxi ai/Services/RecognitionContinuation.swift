import Foundation
import Synchronization

/// Guarantees a checked continuation is resumed exactly once.
///
/// `SFSpeechRecognizer` delivers its results on an arbitrary queue and can
/// report both a result and an error, while a watchdog timeout may fire
/// concurrently. Routing every outcome through `finish` means the first one
/// wins and later ones are dropped, rather than trapping on a double resume.
final class RecognitionContinuation: Sendable {
    private let pending: Mutex<CheckedContinuation<String, any Error>?>

    init(_ continuation: CheckedContinuation<String, any Error>) {
        pending = Mutex(continuation)
    }

    /// Resumes the continuation, or does nothing if it already resumed.
    func finish(_ result: Result<String, any Error>) {
        let continuation = pending.withLock { stored in
            let value = stored
            stored = nil
            return value
        }
        continuation?.resume(with: result)
    }
}
