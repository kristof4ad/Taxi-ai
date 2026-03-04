import CoreLocation
import SwiftUI

/// An arrow that dynamically rotates to point from the user toward a target location,
/// compensating for the device's compass heading so it stays accurate as the user turns.
///
/// Uses cumulative rotation tracking (not clamped to 0–360) so the animation always takes
/// the shortest path, and a deadzone filter to suppress sub-degree compass noise.
struct DirectionArrowView: View {
    var userLocation: CLLocationCoordinate2D?
    var targetLocation: CLLocationCoordinate2D?
    var userHeading: Double?

    /// Cumulative rotation — not clamped to 0–360 so SwiftUI animations
    /// always interpolate via the shortest arc, never spinning the long way.
    @State private var displayRotation: Double = 0

    /// The last normalized target used to compute shortest-path deltas.
    @State private var previousTarget: Double = 0

    /// Whether the initial heading has been captured (skip animation on first value).
    @State private var isInitialized = false

    var body: some View {
        Image(systemName: "location.north.fill")
            .font(.system(size: 80, weight: .medium))
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(displayRotation))
            .onChange(of: targetRotation) { _, newTarget in
                guard isInitialized else {
                    // Snap to the first value without animation.
                    displayRotation = newTarget
                    previousTarget = newTarget
                    isInitialized = true
                    return
                }

                // Compute the shortest-path delta across the 360°/0° boundary.
                var delta = newTarget - previousTarget
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                previousTarget = newTarget

                // Ignore changes smaller than 1° to suppress residual jitter.
                guard abs(delta) > 1 else { return }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    displayRotation += delta
                }
            }
    }

    /// The desired rotation in degrees, normalized to −180…180.
    ///
    /// Computed as the geographic bearing from the user to the target
    /// minus the device's compass heading.
    private var targetRotation: Double {
        guard let userLocation, let targetLocation, let userHeading else {
            return 0
        }

        let bearing = userLocation.bearing(to: targetLocation)
        var angle = (bearing - userHeading).truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        return angle
    }
}
