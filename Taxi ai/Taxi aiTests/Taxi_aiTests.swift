import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct SimulationEngineTests {
    @Test func interpolationAtStartReturnsFirstCoordinate() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
            CLLocationCoordinate2D(latitude: 52.2400, longitude: 21.0200),
        ]
        engine.configure(with: coords)

        let position = engine.interpolatedCoordinate(at: 0)
        #expect(abs(position.latitude - 52.2297) < 0.0001)
        #expect(abs(position.longitude - 21.0122) < 0.0001)
    }

    @Test func interpolationAtEndReturnsLastCoordinate() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
            CLLocationCoordinate2D(latitude: 52.2400, longitude: 21.0200),
        ]
        engine.configure(with: coords)

        let position = engine.interpolatedCoordinate(at: 1.0)
        #expect(abs(position.latitude - 52.2400) < 0.0001)
        #expect(abs(position.longitude - 21.0200) < 0.0001)
    }

    @Test func interpolationAtMidpointReturnsMidCoordinate() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
        ]
        engine.configure(with: coords)

        let position = engine.interpolatedCoordinate(at: 0.5)
        #expect(abs(position.latitude - 5.0) < 0.1)
        #expect(abs(position.longitude - 5.0) < 0.1)
    }

    @Test func interpolationWithEmptyCoordinatesReturnsDefault() {
        let engine = SimulationEngine()
        engine.configure(with: [])

        let position = engine.interpolatedCoordinate(at: 0.5)
        #expect(position.latitude == 0)
        #expect(position.longitude == 0)
    }

    @Test func simulationStartsSetsRunning() async throws {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        engine.configure(with: coords)
        engine.start()

        // Give it a moment to start running.
        try await Task.sleep(for: .milliseconds(50))

        #expect(engine.isRunning)

        engine.stop()
    }

    @Test func resetClearsState() {
        let engine = SimulationEngine()
        let coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        engine.configure(with: coords)
        engine.reset()

        #expect(engine.currentPosition == nil)
        #expect(engine.progress == 0)
    }
}

@MainActor
struct TripViewModelStateTests {
    @Test func initialStateIsIdle() {
        let vm = TripViewModel()
        #expect(vm.simulationState == .idle)
    }

    @Test func onAppearTransitionsToSelectingDestination() {
        let vm = TripViewModel()
        vm.onAppear()
        #expect(vm.simulationState == .selectingDestination)
    }

    @Test func selectDestinationIgnoredWhenNotInSelectingState() {
        let vm = TripViewModel()
        // State is .idle, so selectDestination should be ignored.
        vm.selectDestination(CLLocationCoordinate2D(latitude: 0, longitude: 0))
        #expect(vm.destination == nil)
    }

    @Test func resetTripClearsState() {
        let vm = TripViewModel()
        vm.onAppear()
        vm.resetTrip()

        #expect(vm.destination == nil)
        #expect(vm.route == nil)
        #expect(vm.simulationState == .selectingDestination)
    }

    @Test func startSimulationIgnoredWhenNotRouteReady() {
        let vm = TripViewModel()
        vm.onAppear()
        // State is .selectingDestination, not .routeReady
        vm.startSimulation()
        #expect(vm.simulationState == .selectingDestination)
    }
}
