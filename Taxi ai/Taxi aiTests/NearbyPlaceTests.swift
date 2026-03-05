import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct NearbyPlaceTests {
    // MARK: - Initialization

    @Test func initializesWithCorrectProperties() {
        let place = NearbyPlace(
            id: "place-1",
            name: "Coffee Shop",
            address: "123 Main St",
            coordinate: CLLocationCoordinate2D(latitude: 52.23, longitude: 21.01),
            distance: 500
        )

        #expect(place.id == "place-1")
        #expect(place.name == "Coffee Shop")
        #expect(place.address == "123 Main St")
        #expect(place.coordinate.latitude == 52.23)
        #expect(place.coordinate.longitude == 21.01)
        #expect(place.distance == 500)
    }

    // MARK: - Formatted Distance

    @Test func formattedDistanceForShortDistance() {
        let place = NearbyPlace(
            id: "p1",
            name: "Test",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 160 // ~0.1 miles
        )

        let formatted = place.formattedDistance
        #expect(!formatted.isEmpty)
    }

    @Test func formattedDistanceForOneMile() {
        let place = NearbyPlace(
            id: "p2",
            name: "Test",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 1609.34 // 1 mile
        )

        let formatted = place.formattedDistance
        #expect(!formatted.isEmpty)
    }

    @Test func formattedDistanceForZero() {
        let place = NearbyPlace(
            id: "p3",
            name: "Test",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 0
        )

        let formatted = place.formattedDistance
        #expect(!formatted.isEmpty)
    }

    @Test func formattedDistanceForLargeDistance() {
        let place = NearbyPlace(
            id: "p4",
            name: "Test",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 50_000 // ~31 miles
        )

        let formatted = place.formattedDistance
        #expect(!formatted.isEmpty)
    }

    // MARK: - Identifiable

    @Test func identifiableUsesIdProperty() {
        let place1 = NearbyPlace(
            id: "unique-id",
            name: "Place",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 0
        )
        let place2 = NearbyPlace(
            id: "unique-id",
            name: "Different Name",
            address: "Different Address",
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
            distance: 100
        )

        #expect(place1.id == place2.id)
    }

    @Test func differentIdsAreDistinct() {
        let place1 = NearbyPlace(
            id: "id-1",
            name: "Same Name",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 0
        )
        let place2 = NearbyPlace(
            id: "id-2",
            name: "Same Name",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: 0
        )

        #expect(place1.id != place2.id)
    }
}
