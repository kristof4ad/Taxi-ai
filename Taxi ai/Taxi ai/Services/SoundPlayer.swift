import AVFoundation
import OSLog
import SwiftUI

nonisolated private let log = Logger(subsystem: "com.ikristof.Taxi-ai", category: "Sound")

/// Plays bundled sound effects for vehicle interactions.
///
/// Decoding the clips is the only work done up front, so the instance is created
/// once and shared through the environment rather than per-view. The audio
/// session is deliberately left alone until an effect actually plays.
@MainActor
final class SoundPlayer {
    private let hornPlayer: AVAudioPlayer?
    private let lockPlayer: AVAudioPlayer?
    private let trunkPlayer: AVAudioPlayer?

    /// Pending "stop early" work, keyed by the player it belongs to. Cancelled
    /// on replay so an older tap can't cut short a newer one — which matters
    /// because lock and trunk share a single player when no trunk clip ships.
    private var stopTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// How long the lock and trunk clips play before being cut short.
    private static let shortEffectDuration = Duration.seconds(1.2)

    init() {
        let lock = Self.loadPlayer(for: "car-lock", type: "mp3")
        hornPlayer = Self.loadPlayer(for: "car-horn", type: "mp3")
        lockPlayer = lock
        // Falls back to lock sound if dedicated trunk sound is not available.
        trunkPlayer = Self.loadPlayer(for: "car-trunk", type: "mp3") ?? lock
    }

    /// Plays a short car horn honk.
    func playHorn() {
        guard let player = hornPlayer else { return }
        play(player, stoppingAfter: nil)
    }

    /// Plays a car central locking click sound.
    /// The full clip is ~7 seconds with 6 clicks, so it stops after the first.
    func playLock() {
        guard let player = lockPlayer else { return }
        play(player, stoppingAfter: Self.shortEffectDuration)
    }

    /// Plays an electric trunk actuator sound, cut short to keep it snappy.
    func playTrunk() {
        guard let player = trunkPlayer else { return }
        play(player, stoppingAfter: Self.shortEffectDuration)
    }

    /// Restarts `player`, optionally stopping it early after `duration`.
    private func play(_ player: AVAudioPlayer, stoppingAfter duration: Duration?) {
        activatePlayback()

        let key = ObjectIdentifier(player)
        stopTasks[key]?.cancel()
        stopTasks[key] = nil

        player.currentTime = 0
        player.play()

        guard let duration else { return }
        stopTasks[key] = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            player.stop()
            stopTasks[key] = nil
        }
    }

    /// Claims the process-wide audio session for playback.
    ///
    /// Called at play time rather than at init: `.playback` is non-mixing, so
    /// activating it eagerly would interrupt the user's music or podcast merely
    /// because the app launched. It also re-asserts the category after voice
    /// search has switched the shared session to `.record`.
    private func activatePlayback() {
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
