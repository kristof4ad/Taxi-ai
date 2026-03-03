import SwiftUI

/// The navigation phase of the app.
enum AppScreen {
    case welcome
    case home
    case routePreview
    case rideTracking
    case ride
}

@main
struct Taxi_aiApp: App {
    @State private var homeViewModel = HomeViewModel()
    @State private var tripViewModel: TripViewModel?
    @State private var currentScreen: AppScreen = .welcome

    var body: some Scene {
        WindowGroup {
            switch currentScreen {
            case .welcome:
                WelcomeView {
                    withAnimation {
                        currentScreen = .home
                    }
                }

            case .home:
                HomeView(
                    viewModel: homeViewModel,
                    onPlaceSelected: { place in
                        let trip = TripViewModel(
                            locationService: homeViewModel.locationService
                        )
                        tripViewModel = trip
                        trip.setDestination(from: place)
                        currentScreen = .routePreview
                    }
                )

            case .routePreview:
                if let tripViewModel {
                    RoutePreviewView(
                        viewModel: tripViewModel,
                        onBook: {
                            currentScreen = .rideTracking
                        },
                        onBack: {
                            self.tripViewModel = nil
                            currentScreen = .home
                        }
                    )
                }

            case .rideTracking:
                if let tripViewModel {
                    RideTrackingView(viewModel: tripViewModel)
                }

            case .ride:
                if let tripViewModel {
                    MapView(viewModel: tripViewModel)
                }
            }
        }
    }
}
