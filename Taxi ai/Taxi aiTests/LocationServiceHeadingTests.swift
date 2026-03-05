import CoreLocation
import Testing

@testable import Taxi_ai

@MainActor
struct LocationServiceHeadingTests {
    // MARK: - Initial State

    @Test func userLocationIsNilInitially() {
        let service = LocationService()
        #expect(service.userLocation == nil)
    }

    @Test func userHeadingIsNilInitially() {
        let service = LocationService()
        #expect(service.userHeading == nil)
    }

    @Test func authorizationStatusIsNotDetermined() {
        let service = LocationService()
        #expect(service.authorizationStatus == .notDetermined)
    }

    // MARK: - Heading Smoothing Algorithm (Mathematical Verification)
    //
    // The LocationService uses exponential moving average on cartesian
    // components (cos/sin) to smooth heading values. Since we cannot reliably
    // create CLHeading instances in tests, we verify the math directly.

    @Test func exponentialMovingAverageConvergesOnSteadyInput() {
        // Simulate the EMA algorithm used in LocationService.
        // Given steady input of 90 degrees, the smoothed heading
        // should converge to 90.
        let alpha = 0.15
        var smoothX = 1.0 // cos(0) — initial heading north
        var smoothY = 0.0 // sin(0)

        let targetRadians = 90.0 * .pi / 180.0

        for _ in 0..<50 {
            smoothX += alpha * (cos(targetRadians) - smoothX)
            smoothY += alpha * (sin(targetRadians) - smoothY)
        }

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        #expect(abs(degrees - 90) < 0.1)
    }

    @Test func emaHandlesNorthWraparound() {
        // Verify that the cartesian EMA handles the 0/360 boundary correctly.
        // Start at 350, move to 10 — should go through north, not south.
        let alpha = 0.15

        // Initialize at 350 degrees.
        let startRadians = 350.0 * .pi / 180.0
        var smoothX = cos(startRadians)
        var smoothY = sin(startRadians)

        // Apply 20 updates at 10 degrees.
        let targetRadians = 10.0 * .pi / 180.0
        for _ in 0..<20 {
            smoothX += alpha * (cos(targetRadians) - smoothX)
            smoothY += alpha * (sin(targetRadians) - smoothY)
        }

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        // Should be near 10, not have gone through 180.
        #expect(degrees < 30 || degrees > 340)
    }

    @Test func emaFirstUpdateSetsExactValue() {
        // The LocationService sets initial heading exactly on first update.
        let heading = 135.0
        let radians = heading * .pi / 180.0

        // First heading: set directly.
        let smoothX = cos(radians)
        let smoothY = sin(radians)

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        #expect(abs(degrees - 135) < 0.01)
    }

    @Test func emaGradualChangeProducesLaggingOutput() {
        // When heading gradually changes 0→90, the smoothed output
        // should lag behind the latest value.
        let alpha = 0.15
        var smoothX = 1.0 // cos(0)
        var smoothY = 0.0 // sin(0)

        for i in 0...9 {
            let radians = Double(i) * 10.0 * .pi / 180.0
            smoothX += alpha * (cos(radians) - smoothX)
            smoothY += alpha * (sin(radians) - smoothY)
        }

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        // Should be between 0 and 90, lagging behind the latest input of 90.
        #expect(degrees >= 0)
        #expect(degrees <= 90)
        // Should be closer to 0 than 90 due to smoothing lag.
        #expect(degrees < 50)
    }

    @Test func emaOutputIsAlwaysNormalized() {
        // Verify that the output is always in [0, 360) range
        // for various input headings.
        let alpha = 0.15
        let testHeadings: [Double] = [0, 45, 90, 135, 180, 225, 270, 315, 359]

        for heading in testHeadings {
            let radians = heading * .pi / 180.0
            let smoothX = cos(radians)
            let smoothY = sin(radians)

            var degrees = atan2(smoothY, smoothX) * 180 / .pi
            if degrees < 0 { degrees += 360 }

            #expect(degrees >= 0, "Heading \(heading) produced negative output: \(degrees)")
            #expect(degrees < 360, "Heading \(heading) produced output >= 360: \(degrees)")
            // Output should be close to input for direct initialization.
            #expect(abs(degrees - heading) < 0.01 || abs(degrees - heading - 360) < 0.01)
        }

        // Suppress unused variable warning.
        _ = alpha
    }

    @Test func emaDueSouthConverges() {
        let alpha = 0.15
        let targetRadians = 180.0 * .pi / 180.0
        var smoothX = cos(targetRadians)
        var smoothY = sin(targetRadians)

        // Apply several updates at 180 degrees.
        for _ in 0..<20 {
            smoothX += alpha * (cos(targetRadians) - smoothX)
            smoothY += alpha * (sin(targetRadians) - smoothY)
        }

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        #expect(abs(degrees - 180) < 0.1)
    }

    @Test func emaDueNorthConverges() {
        let alpha = 0.15
        let targetRadians = 0.0
        var smoothX = cos(targetRadians)
        var smoothY = sin(targetRadians)

        for _ in 0..<20 {
            smoothX += alpha * (cos(targetRadians) - smoothX)
            smoothY += alpha * (sin(targetRadians) - smoothY)
        }

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        // 0 degrees or very close to 360.
        #expect(degrees < 0.1 || degrees > 359.9)
    }

    @Test func emaOppositeDirectionWraparound() {
        // Start at 10 degrees, move to 350 degrees — should go through north.
        let alpha = 0.15

        let startRadians = 10.0 * .pi / 180.0
        var smoothX = cos(startRadians)
        var smoothY = sin(startRadians)

        let targetRadians = 350.0 * .pi / 180.0
        for _ in 0..<30 {
            smoothX += alpha * (cos(targetRadians) - smoothX)
            smoothY += alpha * (sin(targetRadians) - smoothY)
        }

        var degrees = atan2(smoothY, smoothX) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        // Should be near 350, having gone through north (not south through 180).
        #expect(degrees > 340 || degrees < 20)
    }
}
