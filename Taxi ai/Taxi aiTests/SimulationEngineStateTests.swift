import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct SimulationEngineStateTests {
    // MARK: - Configuration

    @Test func configureBuildsCorrectDistanceTable() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0), // ~111 m north
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0), // ~111 m further
        ]
        engine.configure(with: coords)

        // Total distance should be approximately 222 m.
        #expect(engine.totalDistance > 200)
        #expect(engine.totalDistance < 250)
    }

    @Test func configureWithSinglePointHasZeroDistance() {
        let engine = SimulationEngine()
        engine.configure(with: [CLLocationCoordinate2D(latitude: 0, longitude: 0)])

        #expect(engine.totalDistance == 0)
    }

    @Test func configureWithEmptyArrayHasZeroDistance() {
        let engine = SimulationEngine()
        engine.configure(with: [])

        #expect(engine.totalDistance == 0)
    }

    @Test func configureTwiceReplacesState() {
        let engine = SimulationEngine()

        // First configuration.
        let short: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
        ]
        engine.configure(with: short)
        let firstDistance = engine.totalDistance

        // Second configuration with longer route.
        let long: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0), // ~1110 m
        ]
        engine.configure(with: long)

        #expect(engine.totalDistance > firstDistance)
    }

    // MARK: - Start Guards

    @Test func startDoesNothingWithEmptyCoordinates() {
        let engine = SimulationEngine()
        engine.configure(with: [])
        engine.start()

        #expect(engine.isRunning == false)
    }

    // MARK: - Pause / Resume Guards

    @Test func pauseIgnoredWhenNotRunning() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        engine.configure(with: coords)

        // Not started, so pause should do nothing.
        engine.pause()
        #expect(engine.isPaused == false)
    }

    @Test func resumeIgnoredWhenNotPaused() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        engine.configure(with: coords)

        // Not paused, so resume should do nothing.
        engine.resume()
        #expect(engine.isRunning == false)
    }

    // MARK: - Reset

    @Test func resetClearsAllState() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        engine.configure(with: coords)
        engine.reset()

        #expect(engine.isRunning == false)
        #expect(engine.isPaused == false)
        #expect(engine.progress == 0)
        #expect(engine.currentPosition == nil)
        #expect(engine.currentBearing == 0)
        #expect(engine.totalDistance == 0)
    }

    // MARK: - Distance Traveled

    @Test func distanceTraveledIsZeroAtStart() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
        ]
        engine.configure(with: coords)

        #expect(engine.distanceTraveled == 0)
    }

    @Test func distanceTraveledScalesWithTotalDistance() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        engine.configure(with: coords)

        // distanceTraveled = progress * totalDistance. Progress starts at 0.
        #expect(engine.distanceTraveled == 0)
        #expect(engine.totalDistance > 0)
    }

    // MARK: - Remaining Coordinates

    @Test func remainingCoordinatesAtStartContainsAllWaypoints() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
        ]
        engine.configure(with: coords)

        // At progress 0 with no currentPosition, remaining starts from the
        // second waypoint onward (since segmentIndex is 0, startIndex is 1).
        let remaining = engine.remainingCoordinates
        #expect(remaining.count >= 2)
        // Last remaining coordinate should match the route endpoint.
        #expect(abs(remaining.last!.latitude - 0.002) < 0.0001)
    }

    @Test func remainingCoordinatesWithEmptyRoute() {
        let engine = SimulationEngine()
        engine.configure(with: [])

        let remaining = engine.remainingCoordinates
        #expect(remaining.isEmpty)
    }

    @Test func remainingCoordinatesWithSinglePoint() {
        let engine = SimulationEngine()
        engine.configure(with: [CLLocationCoordinate2D(latitude: 0, longitude: 0)])

        let remaining = engine.remainingCoordinates
        #expect(remaining.count == 1)
    }

    // MARK: - Interpolation Edge Cases

    @Test func interpolationAtExactlyOneReturnsEnd() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
        ]
        engine.configure(with: coords)

        // Progress 1.0 should return the last coordinate.
        let position = engine.interpolatedCoordinate(at: 1.0)
        #expect(abs(position.latitude - 10) < 0.1)
        #expect(abs(position.longitude - 10) < 0.1)
    }

    @Test func interpolationAtZeroReturnsStart() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 52.0, longitude: 21.0),
            CLLocationCoordinate2D(latitude: 53.0, longitude: 22.0),
        ]
        engine.configure(with: coords)

        let position = engine.interpolatedCoordinate(at: 0)
        #expect(abs(position.latitude - 52.0) < 0.0001)
        #expect(abs(position.longitude - 21.0) < 0.0001)
    }

    @Test func interpolationWithThreeEqualSegments() {
        let engine = SimulationEngine()
        // Three equal-length segments heading north.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 2, longitude: 0),
            CLLocationCoordinate2D(latitude: 3, longitude: 0),
        ]
        engine.configure(with: coords)

        // At 1/3 progress, should be near latitude 1.
        let position = engine.interpolatedCoordinate(at: 1.0 / 3.0)
        #expect(abs(position.latitude - 1.0) < 0.1)

        // At 2/3 progress, should be near latitude 2.
        let position2 = engine.interpolatedCoordinate(at: 2.0 / 3.0)
        #expect(abs(position2.latitude - 2.0) < 0.1)
    }

    @Test func interpolationAtQuarterProgress() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 4, longitude: 0),
        ]
        engine.configure(with: coords)

        let position = engine.interpolatedCoordinate(at: 0.25)
        #expect(abs(position.latitude - 1.0) < 0.1)
    }

    @Test func interpolationWithUnevenSegments() {
        let engine = SimulationEngine()
        // First segment is short (~111 m), second is long (~1110 m).
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0), // ~111 m
            CLLocationCoordinate2D(latitude: 0.011, longitude: 0), // ~1110 m more
        ]
        engine.configure(with: coords)

        // At 50% progress, the position should be well past the first point
        // because distance-based interpolation distributes evenly by distance.
        let position = engine.interpolatedCoordinate(at: 0.5)
        #expect(position.latitude > 0.001) // Past the first waypoint
    }

    // MARK: - Initial State

    @Test func initialStateIsClean() {
        let engine = SimulationEngine()

        #expect(engine.isRunning == false)
        #expect(engine.isPaused == false)
        #expect(engine.progress == 0)
        #expect(engine.currentPosition == nil)
        #expect(engine.currentBearing == 0)
        #expect(engine.totalDistance == 0)
        #expect(engine.distanceTraveled == 0)
    }
}
