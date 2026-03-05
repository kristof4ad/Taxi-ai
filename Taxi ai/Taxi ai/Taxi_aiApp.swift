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
struct Taxi_aiApp: App {
    @State private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(homeViewModel: homeViewModel)
        }
        .modelContainer(for: CompletedRide.self)
    }
}
