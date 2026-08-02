import Speech
import SwiftData
import SwiftUI

/// The navigation phase of the app.
enum AppScreen {
    case welcome
    case home
    case routePreview
    case rideTracking
    case enterVehicle
    case pickupNavigation
    case fastenSeatbelts
    case startRide
    case ride
    case exitVehicle
    case closeDoors
    case rideDetail
    case rideHistory
}

@main
// swiftlint:disable:next type_name
struct Taxi_aiApp: App {
    @State private var homeViewModel = HomeViewModel()
    @State private var intelligenceService = IntelligenceService()
    /// Created once here: initializing it configures the audio session and
    /// decodes three clips, which is wasteful to repeat per screen.
    @State private var soundPlayer = SoundPlayer()

    init() {
        Self.primeSpeechPermission()
    }

    /// Pre-requests speech recognition permission via the raw callback.
    ///
    /// Using `await SFSpeechRecognizer.requestAuthorization()` from a Swift
    /// Concurrency context trips the framework's `unsafeForcedSync` assert,
    /// so we fire the callback variant here. The closure MUST be
    /// `nonisolated` — TCC dispatches the reply on its own XPC queue, and if
    /// the closure inherits `@MainActor` from `App.init` the Swift 6 runtime
    /// isolation check fails with `_dispatch_assert_queue_fail` the first
    /// time the permission prompt is accepted.
    nonisolated private static func primeSpeechPermission() {
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else { return }
        SFSpeechRecognizer.requestAuthorization { _ in
            // Intentionally empty — actual usage reads the status later.
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(homeViewModel: homeViewModel)
                .environment(intelligenceService)
                .environment(\.soundPlayer, soundPlayer)
        }
        .modelContainer(for: CompletedRide.self)
    }
}
