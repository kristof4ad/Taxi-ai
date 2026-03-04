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
                    RideTrackingView(viewModel: tripViewModel) {
                        withAnimation {
                            currentScreen = .enterVehicle
                        }
                    }
                }

            case .enterVehicle:
                if let tripViewModel {
                    EnterVehicleView(
                        viewModel: tripViewModel,
                        onFindVehicle: {
                            withAnimation {
                                currentScreen = .pickupNavigation
                            }
                        },
                        onOpenDoor: {
                            withAnimation {
                                currentScreen = .fastenSeatbelts
                            }
                        }
                    )
                }

            case .pickupNavigation:
                if let tripViewModel {
                    PickupNavigationView(
                        viewModel: tripViewModel,
                        onDismiss: {
                            withAnimation {
                                currentScreen = .enterVehicle
                            }
                        }
                    )
                }

            case .fastenSeatbelts:
                if let tripViewModel {
                    FastenSeatbeltsView(viewModel: tripViewModel) {
                        withAnimation {
                            currentScreen = .startRide
                        }
                    }
                }

            case .startRide:
                if let tripViewModel {
                    StartRideView(viewModel: tripViewModel) {
                        withAnimation {
                            currentScreen = .ride
                        }
                    }
                }

            case .ride:
                if let tripViewModel {
                    RideView(viewModel: tripViewModel)
                }
            }
        }
    }
}
