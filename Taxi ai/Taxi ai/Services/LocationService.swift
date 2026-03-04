import CoreLocation

/// Wraps CLLocationManager to provide user location and heading updates as an observable service.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var userLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// The device's current compass heading in degrees (0 = north, 90 = east, etc.).
    var userHeading: Double?

    private let manager = CLLocationManager()

    // Circular exponential moving average state for heading smoothing.
    // Uses cartesian components to handle the 0°/360° wraparound correctly.
    private var smoothedHeadingX: Double = 1
    private var smoothedHeadingY: Double = 0
    private var hasInitialHeading = false

    /// Controls how quickly the smoothed heading responds to changes.
    /// Lower values = smoother but slower response.
    private let headingSmoothingFactor: Double = 0.15

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    /// Begins delivering compass heading updates for directional guidance.
    func startUpdatingHeading() {
        #if os(iOS)
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
        #endif
    }

    /// Stops compass heading updates.
    func stopUpdatingHeading() {
        #if os(iOS)
        manager.stopUpdatingHeading()
        #endif
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        Task { @MainActor in
            self.userLocation = coordinate
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading = newHeading.trueHeading
        Task { @MainActor in
            let radians = heading * .pi / 180

            if !hasInitialHeading {
                smoothedHeadingX = cos(radians)
                smoothedHeadingY = sin(radians)
                hasInitialHeading = true
            } else {
                // Exponential moving average on cartesian components
                // to handle the 0°/360° wraparound smoothly.
                smoothedHeadingX += headingSmoothingFactor * (cos(radians) - smoothedHeadingX)
                smoothedHeadingY += headingSmoothingFactor * (sin(radians) - smoothedHeadingY)
            }

            var degrees = atan2(smoothedHeadingY, smoothedHeadingX) * 180 / .pi
            if degrees < 0 { degrees += 360 }
            self.userHeading = degrees
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            #if os(iOS)
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdatingLocation()
            }
            #else
            if status == .authorizedAlways {
                self.startUpdatingLocation()
            }
            #endif
        }
    }
}
