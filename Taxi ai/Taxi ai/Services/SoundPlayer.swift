import AVFoundation
import OSLog
import SwiftUI

nonisolated private let log = Logger(subsystem: "com.ikristof.Taxi-ai", category: "Sound")

/// Plays bundled sound effects for vehicle interactions.
///
/// Initialization configures the shared audio session and decodes three clips
/// from the bundle, so the instance is created once and shared through the
/// environment rather than per-view.
@MainActor
final class SoundPlayer {
    private let hornPlayer: AVAudioPlayer?
    private let lockPlayer: AVAudioPlayer?
    private let trunkPlayer: AVAudioPlayer?

    init() {
        Self.activatePlayback()

        let lock = Self.loadPlayer(for: "car-lock", type: "mp3")
        hornPlayer = Self.loadPlayer(for: "car-horn", type: "mp3")
        lockPlayer = lock
        // Falls back to lock sound if dedicated trunk sound is not available.
        trunkPlayer = Self.loadPlayer(for: "car-trunk", type: "mp3") ?? lock
    }

    /// Plays a short car horn honk.
    func playHorn() {
        Self.activatePlayback()
        hornPlayer?.currentTime = 0
        hornPlayer?.play()
    }

    /// Plays a car central locking click sound.
    func playLock() {
        guard let player = lockPlayer else { return }
        Self.activatePlayback()
        player.currentTime = 0
        player.play()

        // The full clip is ~7 seconds with 6 clicks. Stop after the first click.
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            player.stop()
        }
    }

    /// Plays an electric trunk actuator sound.
    func playTrunk() {
        guard let player = trunkPlayer else { return }
        Self.activatePlayback()
        player.currentTime = 0
        player.play()

        // Stop after a short clip to keep it snappy.
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            player.stop()
        }
    }

    /// Puts the process-wide audio session back into playback mode.
    ///
    /// Voice search switches the shared session to `.record` and this player is
    /// created only once at launch, so its initial category would otherwise go
    /// stale after a voice search and effects would play silently.
    private static func activatePlayback() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playback else { return }
        do {
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            log.error("Failed to configure audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Loads an audio player from the app bundle.
    private static func loadPlayer(for resource: String, type: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: type) else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
}

extension EnvironmentValues {
    /// The app-wide sound player, injected once at the root of the scene.
    ///
    /// Optional because the default value is evaluated off the main actor, where
    /// a `@MainActor` instance cannot be constructed.
    @Entry var soundPlayer: SoundPlayer?
}
