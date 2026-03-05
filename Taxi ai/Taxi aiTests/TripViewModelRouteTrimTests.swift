import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct TripViewModelRouteTrimTests {
    // MARK: - Basic Trimming

    @Test func trimRemovesTrailingDistance() {
        // Create a straight route of ~1000 m heading north.
        let start = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let end = CLLocationCoordinate2D(latitude: 52.2387, longitude: 21.0122) // ~1000 m north

        let trimmed = TripViewModel.trimmedRoute([start, end], trailingMeters: 100)

        // Should have 2 coordinates (start + interpolated point).
        #expect(trimmed.count == 2)

        // The trimmed endpoint should be closer to start than the original end.
        let originalDistance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        let trimmedDistance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: trimmed.last!.latitude, longitude: trimmed.last!.longitude))

        // The trimmed route should be approximately 100 m shorter.
        #expect(abs((originalDistance - trimmedDistance) - 100) < 5)
    }

    @Test func trimPreservesIntermediateCoordinates() {
        // Three-point route: start → mid → end
        let start = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let mid = CLLocationCoordinate2D(latitude: 52.2350, longitude: 21.0122) // ~590 m
        let end = CLLocationCoordinate2D(latitude: 52.2400, longitude: 21.0122) // ~590 m further

        let trimmed = TripViewModel.trimmedRoute([start, mid, end], trailingMeters: 100)

        // Should preserve start and mid, plus an interpolated point before end.
        #expect(trimmed.count == 3)
        #expect(trimmed[0].latitude == start.latitude)
        #expect(trimmed[1].latitude == mid.latitude)
    }

    // MARK: - Edge Cases

    @Test func trimWithSingleCoordinateReturnsIt() {
        let point = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let trimmed = TripViewModel.trimmedRoute([point], trailingMeters: 100)

        #expect(trimmed.count == 1)
        #expect(trimmed[0].latitude == point.latitude)
    }

    @Test func trimWithEmptyArrayReturnsEmpty() {
        let trimmed = TripViewModel.trimmedRoute([], trailingMeters: 100)
        #expect(trimmed.isEmpty)
    }

    @Test func trimWithRouteShorterThanThresholdReturnsFirstPoint() {
        // Route of ~50 m (shorter than 100 m threshold).
        let start = CLLocationCoordinate2D(latitude: 52.22970, longitude: 21.0122)
        let end = CLLocationCoordinate2D(latitude: 52.22915, longitude: 21.0122) // ~50 m

        let trimmed = TripViewModel.trimmedRoute([start, end], trailingMeters: 100)

        // Should return just the first coordinate since the entire route is shorter.
        #expect(trimmed.count == 1)
        #expect(trimmed[0].latitude == start.latitude)
    }

    @Test func trimWithZeroTrailingMetersReturnsFullRoute() {
        let start = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let end = CLLocationCoordinate2D(latitude: 52.2400, longitude: 21.0122)

        let trimmed = TripViewModel.trimmedRoute([start, end], trailingMeters: 0)

        // With 0 trailing meters, the fraction calculation yields 1 - 0/length = 1,
        // which means the interpolated point equals the segment endpoint.
        #expect(trimmed.count == 2)
        #expect(abs(trimmed.last!.latitude - end.latitude) < 0.0001)
    }

    // MARK: - Multi-Segment Routes

    @Test func trimCutsWithinCorrectSegment() {
        // Four-point route with varying segment lengths.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122), // Point 0
            CLLocationCoordinate2D(latitude: 52.2350, longitude: 21.0122), // ~590 m from 0
            CLLocationCoordinate2D(latitude: 52.2400, longitude: 21.0122), // ~556 m from 1
            CLLocationCoordinate2D(latitude: 52.2450, longitude: 21.0122), // ~556 m from 2
        ]

        // Trim 200 m — should cut into the last segment.
        let trimmed = TripViewModel.trimmedRoute(coords, trailingMeters: 200)

        // The cut point should be within the last segment,
        // so we should have points 0, 1, 2, and an interpolated point.
        #expect(trimmed.count == 4)

        // The last trimmed point should be between point 2 and point 3.
        #expect(trimmed.last!.latitude > coords[2].latitude)
        #expect(trimmed.last!.latitude < coords[3].latitude)
    }

    @Test func trimAcrossMultipleSegments() {
        // Three short segments of ~100 m each.
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 52.22970, longitude: 21.0122),
            CLLocationCoordinate2D(latitude: 52.23060, longitude: 21.0122), // ~100 m
            CLLocationCoordinate2D(latitude: 52.23150, longitude: 21.0122), // ~100 m
            CLLocationCoordinate2D(latitude: 52.23240, longitude: 21.0122), // ~100 m
        ]

        // Trim 250 m — should consume the last two segments (200 m)
        // and cut 50 m into the first segment.
        let trimmed = TripViewModel.trimmedRoute(coords, trailingMeters: 250)

        // Should have the first point and an interpolated point in the first segment.
        #expect(trimmed.count == 2)

        // Interpolated point should be between point 0 and point 1.
        #expect(trimmed.last!.latitude > coords[0].latitude)
        #expect(trimmed.last!.latitude < coords[1].latitude)
    }

    // MARK: - Accuracy

    @Test func trimmedDistanceMatchesExpectedReduction() {
        let start = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        let end = CLLocationCoordinate2D(latitude: 52.2500, longitude: 21.0122) // ~2260 m

        let trimDistance: Double = 500
        let trimmed = TripViewModel.trimmedRoute([start, end], trailingMeters: trimDistance)

        let originalLength = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        let trimmedLength = CLLocation(latitude: trimmed.first!.latitude, longitude: trimmed.first!.longitude)
            .distance(from: CLLocation(latitude: trimmed.last!.latitude, longitude: trimmed.last!.longitude))

        // The difference should be approximately the trim distance.
        let reduction = originalLength - trimmedLength
        #expect(abs(reduction - trimDistance) < 10) // Within 10 m tolerance
    }
}
