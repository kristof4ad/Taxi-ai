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
    @State private var isRatingPresented = false
    @State private var pendingRating: RideRating?

    var body: some Scene {
        WindowGroup {
            Group {
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
                    },
                    onShowRideHistory: {
                        withAnimation {
                            currentScreen = .rideHistory
                        }
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
                        },
                        onCancel: {
                            cancelOrder()
                        },
                        onShowRideHistory: {
                            showRideHistoryPreRide()
                        }
                    )
                }

            case .rideTracking:
                if let tripViewModel {
                    RideTrackingView(
                        viewModel: tripViewModel,
                        onGoToVehicle: {
                            withAnimation {
                                currentScreen = .enterVehicle
                            }
                        },
                        onCancel: {
                            cancelOrder()
                        },
                        onShowRideHistory: {
                            showRideHistoryPreRide()
                        }
                    )
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
                        },
                        onCancel: {
                            cancelOrder()
                        },
                        onShowRideHistory: {
                            showRideHistoryPreRide()
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
                    FastenSeatbeltsView(
                        viewModel: tripViewModel,
                        onFastened: {
                            withAnimation {
                                currentScreen = .startRide
                            }
                        },
                        onCancel: {
                            cancelOrder()
                        },
                        onShowRideHistory: {
                            showRideHistoryPreRide()
                        }
                    )
                }

            case .startRide:
                if let tripViewModel {
                    StartRideView(
                        viewModel: tripViewModel,
                        onStartRide: {
                            withAnimation {
                                currentScreen = .ride
                            }
                        },
                        onCancel: {
                            cancelOrder()
                        },
                        onShowRideHistory: {
                            showRideHistoryPreRide()
                        }
                    )
                }

            case .ride:
                if let tripViewModel {
                    RideView(
                        viewModel: tripViewModel,
                        onArrived: {
                            currentScreen = .exitVehicle
                        },
                        onCancel: {
                            // During ride: go through safe exit flow
                            withAnimation {
                                currentScreen = .exitVehicle
                            }
                        },
                        onShowRideHistory: {
                            // Same as cancel — must exit safely first
                            withAnimation {
                                currentScreen = .exitVehicle
                            }
                        }
                    )
                }

            case .exitVehicle:
                if let tripViewModel {
                    ExitVehicleView(
                        viewModel: tripViewModel,
                        onRateRide: {
                            isRatingPresented = true
                        },
                        onOpenDoor: {
                            withAnimation {
                                currentScreen = .closeDoors
                            }
                        },
                        onCancel: {
                            // Skip to ride detail so ride gets recorded
                            withAnimation {
                                currentScreen = .rideDetail
                            }
                        },
                        onShowRideHistory: {
                            withAnimation {
                                currentScreen = .rideDetail
                            }
                        }
                    )
                }

            case .closeDoors:
                if let tripViewModel {
                    CloseDoorsView(
                        viewModel: tripViewModel,
                        onRateRide: {
                            isRatingPresented = true
                        },
                        onFinishRide: {
                            withAnimation {
                                currentScreen = .rideDetail
                            }
                        },
                        onCancel: {
                            // Skip to ride detail so ride gets recorded
                            withAnimation {
                                currentScreen = .rideDetail
                            }
                        },
                        onShowRideHistory: {
                            withAnimation {
                                currentScreen = .rideDetail
                            }
                        }
                    )
                }

            case .rideDetail:
                if let tripViewModel {
                    RideDetailView(
                        viewModel: tripViewModel,
                        rating: pendingRating,
                        onFinished: {
                            recordRideAndShowHistory(tripViewModel)
                        },
                        onCancel: {
                            recordRideAndShowHistory(tripViewModel)
                        },
                        onShowRideHistory: {
                            recordRideAndShowHistory(tripViewModel)
                        }
                    )
                }

            case .rideHistory:
                RideHistoryView(rides: homeViewModel.completedRides) {
                    withAnimation {
                        currentScreen = .home
                    }
                }
            }
            }
            .sheet(isPresented: $isRatingPresented) {
                if let tripViewModel {
                    RateRideView(
                        viewModel: RateRideViewModel(
                            ridePrice: tripViewModel.estimatedPrice ?? 0,
                            currencyCode: tripViewModel.displayCurrencyCode,
                            existingRating: pendingRating
                        ),
                        onSubmit: { rating in
                            pendingRating = rating
                            isRatingPresented = false
                        },
                        onDismiss: {
                            isRatingPresented = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Menu Actions

    /// Cancels a pre-ride order, clearing the trip and returning to Home.
    private func cancelOrder() {
        withAnimation {
            tripViewModel = nil
            currentScreen = .home
        }
    }

    /// Shows ride history from a pre-ride screen, clearing the active trip.
    private func showRideHistoryPreRide() {
        withAnimation {
            tripViewModel = nil
            currentScreen = .rideHistory
        }
    }

    /// Records the completed ride to history and navigates to the ride history screen.
    private func recordRideAndShowHistory(_ trip: TripViewModel) {
        var completedRide = CompletedRide(
            date: .now,
            pickupName: trip.pickupAddress ?? "Pickup",
            destinationName: trip.destinationName ?? "Destination",
            price: trip.estimatedPrice ?? 0,
            currencyCode: trip.displayCurrencyCode
        )

        // Attach rating data if the user rated during this ride.
        if let rating = pendingRating {
            completedRide.starRating = rating.starRating
            completedRide.feedbackText = rating.feedbackText.isEmpty ? nil : rating.feedbackText
            completedRide.tipPercentage = rating.tipPercentage
            completedRide.tipAmount = rating.tipAmount
        }

        homeViewModel.addCompletedRide(completedRide)
        withAnimation {
            tripViewModel = nil
            pendingRating = nil
            currentScreen = .rideHistory
        }
    }
}
