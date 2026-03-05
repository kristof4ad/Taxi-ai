import CoreLocation
import Testing

@testable import Taxi_ai

struct BearingCalculationTests {
    // MARK: - Cardinal Directions

    @Test func bearingDueNorth() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 10, longitude: 0)

        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 0) < 0.1)
    }

    @Test func bearingDueEast() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 10)

        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 90) < 0.1)
    }

    @Test func bearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 10, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 180) < 0.1)
    }

    @Test func bearingDueWest() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: -10)

        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 270) < 0.1)
    }

    // MARK: - Intercardinal Directions

    @Test func bearingNortheast() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 10, longitude: 10)

        let bearing = from.bearing(to: to)
        // Northeast is roughly 45°, but varies slightly due to Earth's curvature.
        #expect(bearing > 40 && bearing < 50)
    }

    @Test func bearingSouthwest() {
        let from = CLLocationCoordinate2D(latitude: 10, longitude: 10)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let bearing = from.bearing(to: to)
        // Southwest is roughly 225°.
        #expect(bearing > 220 && bearing < 230)
    }

    // MARK: - Edge Cases

    @Test func bearingToSamePointReturnsZero() {
        let point = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let bearing = point.bearing(to: point)

        // atan2(0, 0) = 0, so bearing to same point should be 0.
        #expect(bearing == 0)
    }

    @Test func bearingIsAlwaysPositive() {
        let from = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)

        // Test multiple directions to ensure the result is always 0...360.
        let destinations = [
            CLLocationCoordinate2D(latitude: 53, longitude: 21), // North
            CLLocationCoordinate2D(latitude: 52, longitude: 22), // East
            CLLocationCoordinate2D(latitude: 51, longitude: 21), // South
            CLLocationCoordinate2D(latitude: 52, longitude: 20), // West
        ]

        for destination in destinations {
            let bearing = from.bearing(to: destination)
            #expect(bearing >= 0 && bearing < 360)
        }
    }

    // MARK: - Real-World Coordinates

    @Test func bearingWarsawToKrakow() {
        // Warsaw is roughly south-southwest of Krakow.
        let warsaw = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let krakow = CLLocationCoordinate2D(latitude: 50.0647, longitude: 19.9450)

        let bearing = warsaw.bearing(to: krakow)
        // Expected: roughly 195-200° (south-southwest).
        #expect(bearing > 190 && bearing < 210)
    }

    @Test func bearingIsReversible() {
        let pointA = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let pointB = CLLocationCoordinate2D(latitude: 50.0647, longitude: 19.9450)

        let forward = pointA.bearing(to: pointB)
        let backward = pointB.bearing(to: pointA)

        // Forward and backward bearings should differ by approximately 180°.
        var difference = abs(forward - backward)
        if difference > 180 { difference = 360 - difference }
        #expect(abs(difference - 180) < 5) // Within 5° (great circle effect)
    }

    // MARK: - Near Poles and Meridian Crossings

    @Test func bearingAcrossDateLine() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 179)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: -179)

        let bearing = from.bearing(to: to)
        // Crossing the date line heading east: should be ~90°.
        #expect(abs(bearing - 90) < 1)
    }

    @Test func bearingNearEquator() {
        let from = CLLocationCoordinate2D(latitude: 0.001, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0.001, longitude: 1)

        let bearing = from.bearing(to: to)
        // Due east along the equator.
        #expect(abs(bearing - 90) < 0.1)
    }
}
