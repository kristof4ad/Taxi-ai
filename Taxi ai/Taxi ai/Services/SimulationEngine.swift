import CoreLocation

/// Animates a position along a route at constant speed using distance-based interpolation.
@MainActor
@Observable
final class SimulationEngine {
    /// Current position of the simulated vehicle.
    var currentPosition: CLLocationCoordinate2D?

    /// Current bearing of the vehicle in degrees (0 = north, 90 = east).
    var currentBearing: Double = 0

    /// Progress from 0.0 to 1.0 along the route.
    var progress: Double = 0

    /// Whether the simulation is actively running.
    var isRunning = false

    /// Whether the simulation is currently paused and can be resumed.
    private(set) var isPaused = false

    /// Stored progress when the simulation is paused, allowing it to resume from this point.
    private var pausedProgress: Double?

    private var simulationTask: Task<Void, Never>?

    /// Duration of the simulation in seconds (faster than real time for demo purposes).
    private let simulationDuration: TimeInterval = 15.0

    /// Extracted coordinates from the route polyline.
    private var routeCoordinates: [CLLocationCoordinate2D] = []

    /// Cumulative distances at each coordinate index for distance-based interpolation.
    private var cumulativeDistances: [CLLocationDistance] = []

    /// Total route length in meters.
    private(set) var totalDistance: CLLocationDistance = 0

    /// Distance traveled so far in meters, based on current progress.
    var distanceTraveled: CLLocationDistance {
        progress * totalDistance
    }

    /// Configures the engine with route coordinates.
    func configure(with coordinates: [CLLocationCoordinate2D]) {
        routeCoordinates = coordinates
        buildDistanceTable()
    }

    /// Starts the simulation from the beginning of the route.
    func start() {
        guard !routeCoordinates.isEmpty else { return }
        isRunning = true
        progress = 0
        currentPosition = routeCoordinates.first
        currentBearing = segmentBearing(at: 0)

        simulationTask = Task {
            let startTime = ContinuousClock.now

            while !Task.isCancelled {
                let elapsed = ContinuousClock.now - startTime
                let elapsedSeconds = elapsed / .seconds(1)
                let newProgress = min(elapsedSeconds / simulationDuration, 1.0)

                self.progress = newProgress
                self.currentPosition = interpolatedCoordinate(at: newProgress)
                self.currentBearing = segmentBearing(at: newProgress)

                if newProgress >= 1.0 {
                    self.isRunning = false
                    return
                }

                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// Pauses the simulation, preserving current progress so it can be resumed later.
    func pause() {
        guard isRunning else { return }
        pausedProgress = progress
        isPaused = true
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
    }

    /// Resumes the simulation from where it was paused.
    func resume() {
        guard let savedProgress = pausedProgress, !routeCoordinates.isEmpty else { return }
        pausedProgress = nil
        isPaused = false
        isRunning = true

        let resumeFrom = savedProgress
        simulationTask = Task {
            let startTime = ContinuousClock.now

            while !Task.isCancelled {
                let elapsed = ContinuousClock.now - startTime
                let elapsedSeconds = elapsed / .seconds(1)
                let newProgress = min(resumeFrom + elapsedSeconds / simulationDuration, 1.0)

                self.progress = newProgress
                self.currentPosition = interpolatedCoordinate(at: newProgress)
                self.currentBearing = segmentBearing(at: newProgress)

                if newProgress >= 1.0 {
                    self.isRunning = false
                    return
                }

                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// Stops the simulation.
    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
    }

    /// Resets all simulation state.
    func reset() {
        stop()
        isPaused = false
        pausedProgress = nil
        progress = 0
        currentPosition = nil
        currentBearing = 0
        routeCoordinates = []
        cumulativeDistances = []
        totalDistance = 0
    }

    // MARK: - Distance-Based Interpolation

    /// Builds a cumulative distance table for constant-speed interpolation.
    ///
    /// Without this, the dot would move unevenly because route segments vary in length.
    /// Highway segments might span hundreds of meters while city turns span only a few.
    private func buildDistanceTable() {
        guard routeCoordinates.count >= 2 else {
            cumulativeDistances = []
            totalDistance = 0
            return
        }

        cumulativeDistances = [0]
        var running: CLLocationDistance = 0

        for i in 1..<routeCoordinates.count {
            let from = CLLocation(
                latitude: routeCoordinates[i - 1].latitude,
                longitude: routeCoordinates[i - 1].longitude
            )
            let to = CLLocation(
                latitude: routeCoordinates[i].latitude,
                longitude: routeCoordinates[i].longitude
            )
            running += from.distance(from: to)
            cumulativeDistances.append(running)
        }
        totalDistance = running
    }

    /// Returns the remaining route coordinates from the current position to the end.
    var remainingCoordinates: [CLLocationCoordinate2D] {
        guard routeCoordinates.count >= 2, totalDistance > 0 else {
            return routeCoordinates
        }

        let targetDistance = progress * totalDistance

        // Find the segment containing the current position.
        var segmentIndex = 0
        for i in 1..<cumulativeDistances.count {
            if cumulativeDistances[i] >= targetDistance {
                segmentIndex = i - 1
                break
            }
            segmentIndex = i - 1
        }

        // Start with the current interpolated position, then all remaining waypoints.
        var remaining: [CLLocationCoordinate2D] = []
        if let current = currentPosition {
            remaining.append(current)
        }
        let startIndex = min(segmentIndex + 1, routeCoordinates.count - 1)
        remaining.append(contentsOf: routeCoordinates[startIndex...])
        return remaining
    }

    /// Returns the bearing (in degrees) for the route segment at the given progress.
    ///
    /// If the current segment has zero length (duplicate coordinates),
    /// scans ahead for the next distinct coordinate to determine direction.
    private func segmentBearing(at progress: Double) -> Double {
        guard routeCoordinates.count >= 2, totalDistance > 0 else { return currentBearing }

        let targetDistance = progress * totalDistance

        var segmentIndex = 0
        for i in 1..<cumulativeDistances.count {
            if cumulativeDistances[i] >= targetDistance {
                segmentIndex = i - 1
                break
            }
            segmentIndex = i - 1
        }

        let nextIndex = min(segmentIndex + 1, routeCoordinates.count - 1)
        let from = routeCoordinates[segmentIndex]
        let to = routeCoordinates[nextIndex]

        // If the segment is zero-length, look ahead for a distinct point.
        if from.latitude == to.latitude, from.longitude == to.longitude {
            for i in (nextIndex + 1)..<routeCoordinates.count {
                let ahead = routeCoordinates[i]
                if ahead.latitude != from.latitude || ahead.longitude != from.longitude {
                    return from.bearing(to: ahead)
                }
            }
            return currentBearing
        }

        return from.bearing(to: to)
    }

    /// Returns the interpolated coordinate at a given progress fraction (0.0 to 1.0).
    func interpolatedCoordinate(at progress: Double) -> CLLocationCoordinate2D {
        guard routeCoordinates.count >= 2, totalDistance > 0 else {
            return routeCoordinates.first ?? CLLocationCoordinate2D()
        }

        let targetDistance = progress * totalDistance

        // Find the segment that contains this distance.
        var segmentIndex = 0
        for i in 1..<cumulativeDistances.count {
            if cumulativeDistances[i] >= targetDistance {
                segmentIndex = i - 1
                break
            }
            segmentIndex = i - 1
        }

        // Guard against out-of-bounds.
        let nextIndex = min(segmentIndex + 1, routeCoordinates.count - 1)
        let segmentStart = cumulativeDistances[segmentIndex]
        let segmentEnd = cumulativeDistances[nextIndex]
        let segmentLength = segmentEnd - segmentStart

        let segmentFraction: Double
        if segmentLength > 0 {
            segmentFraction = (targetDistance - segmentStart) / segmentLength
        } else {
            segmentFraction = 0
        }

        let from = routeCoordinates[segmentIndex]
        let to = routeCoordinates[nextIndex]

        return CLLocationCoordinate2D(
            latitude: from.latitude + (to.latitude - from.latitude) * segmentFraction,
            longitude: from.longitude + (to.longitude - from.longitude) * segmentFraction
        )
    }
}
