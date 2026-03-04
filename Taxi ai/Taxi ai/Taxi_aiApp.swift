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
                    RideView(viewModel: tripViewModel) {
                        currentScreen = .exitVehicle
                    }
                }

            case .exitVehicle:
                if let tripViewModel {
                    ExitVehicleView(
                        viewModel: tripViewModel,
                        onRateRide: {
                            // Rate ride flow placeholder
                        },
                        onOpenDoor: {
                            withAnimation {
                                currentScreen = .closeDoors
                            }
                        }
                    )
                }

            case .closeDoors:
                if let tripViewModel {
                    CloseDoorsView(viewModel: tripViewModel) {
                        withAnimation {
                            currentScreen = .rideDetail
                        }
                    }
                }

            case .rideDetail:
                if let tripViewModel {
                    RideDetailView(viewModel: tripViewModel) {
                        // Save the completed ride to history
                        let completedRide = CompletedRide(
                            date: .now,
                            pickupName: "Pickup",
                            destinationName: tripViewModel.destinationName ?? "Destination",
                            price: tripViewModel.estimatedPrice ?? 0,
                            currencyCode: tripViewModel.displayCurrencyCode
                        )
                        homeViewModel.addCompletedRide(completedRide)
                        withAnimation {
                            self.tripViewModel = nil
                            currentScreen = .rideHistory
                        }
                    }
                }

            case .rideHistory:
                RideHistoryView(rides: homeViewModel.completedRides) {
                    withAnimation {
                        currentScreen = .home
                    }
                }
            }
        }
    }
}
