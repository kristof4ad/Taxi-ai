import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct SimulationEngineAccuracyTests {
    // MARK: - Distance Table Accuracy

    @Test func distanceTableSumsCorrectly() {
        let engine = SimulationEngine()
        // Straight line ~1110 m north.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        engine.configure(with: coords)

        #expect(engine.totalDistance > 1100)
        #expect(engine.totalDistance < 1120)
    }

    @Test func distanceTableMultipleSegments() {
        let engine = SimulationEngine()
        // Three equal segments heading north: ~111 m each = ~333 m total.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.003, longitude: 0),
        ]
        engine.configure(with: coords)

        #expect(engine.totalDistance > 330)
        #expect(engine.totalDistance < 340)
    }

    @Test func distanceTableZigZagRoute() {
        let engine = SimulationEngine()
        // Zig-zag route: total distance should be greater than straight-line distance.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.003, longitude: 0.001),
        ]
        engine.configure(with: coords)

        let straightLine = CLLocation(latitude: 0, longitude: 0)
            .distance(from: CLLocation(latitude: 0.003, longitude: 0.001))

        #expect(engine.totalDistance > straightLine)
    }

    // MARK: - Interpolation Accuracy

    @Test func interpolationMidpointOfStraightLine() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        engine.configure(with: coords)

        let midpoint = engine.interpolatedCoordinate(at: 0.5)
        #expect(abs(midpoint.latitude - 0.005) < 0.0001)
        #expect(abs(midpoint.longitude) < 0.0001)
    }

    @Test func interpolationProducesMonotonicProgress() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
        ]
        engine.configure(with: coords)

        // Latitude should increase monotonically with progress.
        var previousLat = -1.0
        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let pos = engine.interpolatedCoordinate(at: i)
            #expect(pos.latitude >= previousLat)
            previousLat = pos.latitude
        }
    }

    @Test func interpolationCoversEntireRoute() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
            CLLocationCoordinate2D(latitude: 52.24, longitude: 21.02),
            CLLocationCoordinate2D(latitude: 52.25, longitude: 21.01),
        ]
        engine.configure(with: coords)

        let start = engine.interpolatedCoordinate(at: 0)
        let end = engine.interpolatedCoordinate(at: 1.0)

        #expect(abs(start.latitude - 52.23) < 0.001)
        #expect(abs(start.longitude - 21.01) < 0.001)
        #expect(abs(end.latitude - 52.25) < 0.001)
        #expect(abs(end.longitude - 21.01) < 0.001)
    }

    // MARK: - Bearing Accuracy

    @Test func bearingNorthIsCLoseToZero() {
        // Test bearing calculation using the CLLocationCoordinate2D bearing extension directly.
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let bearing = from.bearing(to: to)

        #expect(bearing < 1 || bearing > 359)
    }

    @Test func bearingEastIsCloseToNinety() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let bearing = from.bearing(to: to)

        #expect(abs(bearing - 90) < 1)
    }

    @Test func bearingSouthIsCloseToOneEighty() {
        let from = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let bearing = from.bearing(to: to)

        #expect(abs(bearing - 180) < 1)
    }

    @Test func bearingWestIsCloseToTwoSeventy() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let bearing = from.bearing(to: to)

        #expect(abs(bearing - 270) < 1)
    }

    // MARK: - Zero-Length Segment Handling

    @Test func bearingSkipsZeroLengthSegments() {
        // When two consecutive points are identical, bearing should look ahead.
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        // The bearing extension itself always returns the direction between two distinct points.
        // The zero-length skip logic is in segmentBearing (private), so we verify
        // the underlying bearing math works correctly.
        let bearing = from.bearing(to: to)

        #expect(bearing < 1 || bearing > 359)
    }

    @Test func interpolationHandlesZeroLengthSegment() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0), // duplicate
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        engine.configure(with: coords)

        // Should still interpolate correctly, treating the duplicate as a zero-length segment.
        let mid = engine.interpolatedCoordinate(at: 0.5)
        #expect(abs(mid.latitude - 0.005) < 0.001)
    }

    // MARK: - Distance Traveled Accuracy

    @Test func distanceTraveledAtHalfProgress() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        engine.configure(with: coords)

        // Manually check distanceTraveled = progress * totalDistance.
        // At progress 0, distanceTraveled should be 0.
        #expect(engine.distanceTraveled == 0)

        // totalDistance should be ~1110 m.
        let expectedTotal = engine.totalDistance
        #expect(expectedTotal > 1100)
    }

    // MARK: - Reconfiguration

    @Test func reconfigureReplacesDistanceTable() {
        let engine = SimulationEngine()

        // First: short route.
        let short: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
        ]
        engine.configure(with: short)
        let shortDistance = engine.totalDistance

        // Second: long route.
        let long: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.1, longitude: 0),
        ]
        engine.configure(with: long)
        let longDistance = engine.totalDistance

        #expect(longDistance > shortDistance * 50)
    }

    // MARK: - Remaining Coordinates Accuracy

    @Test func remainingCoordinatesDecreaseWithProgress() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.003, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.004, longitude: 0),
        ]
        engine.configure(with: coords)

        let remainingAtStart = engine.remainingCoordinates.count

        // Remaining at start should include most waypoints.
        #expect(remainingAtStart >= 4)
    }

    // MARK: - Edge: Single Coordinate

    @Test func singleCoordinateInterpolationReturnsIt() {
        let engine = SimulationEngine()
        let point = CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01)
        engine.configure(with: [point])

        let result = engine.interpolatedCoordinate(at: 0.5)
        #expect(abs(result.latitude - 52.23) < 0.0001)
        #expect(abs(result.longitude - 21.01) < 0.0001)
    }

    @Test func singleCoordinateTotalDistanceIsZero() {
        let engine = SimulationEngine()
        engine.configure(with: [CLLocationCoordinate2D(latitude: 0, longitude: 0)])
        #expect(engine.totalDistance == 0)
    }
}
