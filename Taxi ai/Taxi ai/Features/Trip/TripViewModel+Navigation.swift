import MapKit
import SwiftUI

// MARK: - Pickup Approach & Route Helpers

extension TripViewModel {
    /// Starts the car approaching the pickup location along real roads from a random nearby position.
    func startPickupApproach() {
        guard let userLocation = locationService.userLocation else { return }

        let startPosition = randomNearbyPosition(around: userLocation)
        pickupCarPosition = startPosition
        simulationState = .approachingPickup(progress: 0)

        pickupApproachTask = Task {
            // Calculate a real driving route from the random start to the user's pickup.
            do {
                let approachRoute = try await routeService.calculateRoute(
                    from: startPosition,
                    to: userLocation
                )
                pickupRoute = approachRoute

                // Zoom camera to show the approach route area (car → pickup).
                let approachRect = approachRoute.polyline.boundingMapRect
                let paddedRect = approachRect.insetBy(
                    dx: -approachRect.size.width * 0.5,
                    dy: -approachRect.size.height * 0.5
                )
                cameraPosition = .region(MKCoordinateRegion(paddedRect))

                // Trim the route to stop ~100 m before the end so the car stays on the road
                // rather than pulling up to the user's exact position.
                let trimmedCoordinates = Self.trimmedRoute(
                    approachRoute.coordinates,
                    trailingMeters: 100
                )
                pickupStopLocation = trimmedCoordinates.last ?? userLocation

                // Configure the pickup simulation engine and start it.
                pickupSimulationEngine.configure(with: trimmedCoordinates)
                pickupSimulationEngine.start()

                // Monitor the engine's progress.
                while pickupSimulationEngine.isRunning {
                    if let position = pickupSimulationEngine.currentPosition {
                        pickupCarPosition = position
                    }
                    simulationState = .approachingPickup(progress: pickupSimulationEngine.progress)
                    try? await Task.sleep(for: .milliseconds(16))
                }

                pickupCarPosition = pickupStopLocation
                simulationState = .arrivedAtPickup
            } catch {
                // If route calculation fails, fall back to arrived state.
                pickupCarPosition = userLocation
                pickupStopLocation = userLocation
                simulationState = .arrivedAtPickup
            }
        }
    }

    /// Recenters the camera to show the full pickup approach route (car to pickup).
    func recenterPickupCamera() {
        guard let pickupRoute else { return }
        let rect = pickupRoute.polyline.boundingMapRect
        let padded = rect.insetBy(
            dx: -rect.size.width * 0.5,
            dy: -rect.size.height * 0.5
        )
        cameraPosition = .region(MKCoordinateRegion(padded))
    }

    /// Generates a random position ~1-2 km from the given coordinate in a random direction.
    func randomNearbyPosition(
        around center: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let bearingRad = Double.random(in: 0..<(2 * .pi))
        let distance = Double.random(in: 800...1500)
        let lat = center.latitude + (distance / 111_320) * cos(bearingRad)
        let lon = center.longitude
            + (distance / (111_320 * cos(center.latitude * .pi / 180)))
            * sin(bearingRad)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Returns the route coordinates with the trailing segment trimmed so the car stops
    /// approximately `trailingMeters` before the route's end.
    static func trimmedRoute(
        _ coordinates: [CLLocationCoordinate2D],
        trailingMeters: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }

        // Walk backwards through the route, accumulating distance until we hit the threshold.
        var remaining = trailingMeters
        var cutIndex = coordinates.count - 1

        while cutIndex > 0 {
            let from = CLLocation(
                latitude: coordinates[cutIndex - 1].latitude,
                longitude: coordinates[cutIndex - 1].longitude
            )
            let to = CLLocation(
                latitude: coordinates[cutIndex].latitude,
                longitude: coordinates[cutIndex].longitude
            )
            let segmentLength = from.distance(from: to)

            if segmentLength >= remaining {
                // The cut point falls within this segment — interpolate.
                let fraction = 1 - remaining / segmentLength
                let interpolated = CLLocationCoordinate2D(
                    latitude: coordinates[cutIndex - 1].latitude
                        + (coordinates[cutIndex].latitude - coordinates[cutIndex - 1].latitude)
                        * fraction,
                    longitude: coordinates[cutIndex - 1].longitude
                        + (coordinates[cutIndex].longitude - coordinates[cutIndex - 1].longitude)
                        * fraction
                )
                var trimmed = Array(coordinates.prefix(cutIndex))
                trimmed.append(interpolated)
                return trimmed
            }

            remaining -= segmentLength
            cutIndex -= 1
        }

        // Route is shorter than trailingMeters — just return the first point.
        return [coordinates[0]]
    }

    // TODO: Migrate to MKAddressRepresentations when API stabilizes
    /// Reverse geocodes the user's current location to capture a short pickup address (street + city).
    func reverseGeocodePickupLocation() {
        guard let location = locationService.userLocation else { return }

        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        guard let request = MKReverseGeocodingRequest(location: clLocation) else { return }

        request.getMapItems { [weak self] items, _ in
            guard let self,
                  let shortAddress = items?.first?.address?.shortAddress,
                  !shortAddress.isEmpty else { return }
            let address = shortAddress
            guard !address.isEmpty else { return }
            Task { @MainActor in
                self.pickupAddress = address
            }
        }
    }

    /// Calculates a route from the user's current location to the destination.
    func calculateRoute() async {
        guard let origin = locationService.userLocation,
              let destination else { return }

        simulationState = .calculatingRoute

        do {
            let calculatedRoute = try await routeService.calculateRoute(
                from: origin,
                to: destination
            )
            route = calculatedRoute
            tripInfo = TripInfo(
                distance: calculatedRoute.distance,
                expectedTravelTime: calculatedRoute.expectedTravelTime,
                routeName: calculatedRoute.name
            )

            // Zoom camera to show the entire route.
            let mapRect = calculatedRoute.polyline.boundingMapRect
            let paddedRect = mapRect.insetBy(
                dx: -mapRect.size.width * 0.2,
                dy: -mapRect.size.height * 0.2
            )
            cameraPosition = .region(MKCoordinateRegion(paddedRect))

            simulationState = .routeReady
        } catch {
            simulationState = .error(error.localizedDescription)
        }
    }
}
