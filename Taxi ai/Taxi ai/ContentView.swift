import SwiftData
import SwiftUI

/// Root content view managing screen navigation and ride persistence.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    var homeViewModel: HomeViewModel
    @State private var tripViewModel: TripViewModel?
    @State private var currentScreen: AppScreen = .welcome
    @State private var isRatingPresented = false
    @State private var pendingRating: RideRating?

    var body: some View {
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
                        onShowRideHistory: {
                            recordRideAndShowHistory(tripViewModel)
                        }
                    )
                }

            case .rideHistory:
                RideHistoryView {
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

    /// Records the completed ride to SwiftData and navigates to the ride history screen.
    /// Takes a map snapshot of the route before clearing the trip data.
    private func recordRideAndShowHistory(_ trip: TripViewModel) {
        Task {
            // Capture a map snapshot while the route data is still available.
            var snapshotData: Data?
            if let route = trip.route, let destination = trip.destination {
                snapshotData = await MapSnapshotService.takeSnapshot(
                    route: route,
                    destination: destination
                )
            }

            let completedRide = CompletedRide(
                date: .now,
                pickupName: trip.pickupAddress ?? "Pickup",
                destinationName: trip.destinationName ?? "Destination",
                price: trip.estimatedPrice ?? 0,
                currencyCode: trip.displayCurrencyCode,
                mapSnapshotData: snapshotData
            )

            // Attach rating data if the user rated during this ride.
            if let rating = pendingRating {
                completedRide.starRating = rating.starRating
                completedRide.feedbackText = rating.feedbackText.isEmpty ? nil : rating.feedbackText
                completedRide.tipPercentage = rating.tipPercentage
                completedRide.tipAmount = rating.tipAmount
            }

            modelContext.insert(completedRide)

            withAnimation {
                tripViewModel = nil
                pendingRating = nil
                currentScreen = .rideHistory
            }
        }
    }
}
