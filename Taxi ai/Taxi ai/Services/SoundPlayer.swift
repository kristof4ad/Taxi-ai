import AVFoundation

/// Plays bundled sound effects for vehicle interactions.
@MainActor
final class SoundPlayer {
    private var hornPlayer: AVAudioPlayer?
    private var lockPlayer: AVAudioPlayer?
    private var trunkPlayer: AVAudioPlayer?

    init() {
        hornPlayer = Self.loadPlayer(for: "car-horn", type: "mp3")
        lockPlayer = Self.loadPlayer(for: "car-lock", type: "mp3")
        // Falls back to lock sound if dedicated trunk sound is not available.
        trunkPlayer = Self.loadPlayer(for: "car-trunk", type: "mp3") ?? lockPlayer
    }

    /// Plays a short car horn honk.
    func playHorn() {
        hornPlayer?.currentTime = 0
        hornPlayer?.play()
    }

    /// Plays a car central locking click sound.
    func playLock() {
        guard let player = lockPlayer else { return }
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
        player.currentTime = 0
        player.play()

        // Stop after a short clip to keep it snappy.
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            player.stop()
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
