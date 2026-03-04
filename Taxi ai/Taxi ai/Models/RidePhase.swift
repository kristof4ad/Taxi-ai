/// Describes the current phase of a ride for determining menu behavior.
///
/// - `none`: No ride in progress (Home screen). Menu shows only "List of rides".
/// - `ordering`: Ride is being ordered but hasn't started (RoutePreview through StartRide).
///   Cancel label is "Cancel the order" and the ride is not recorded.
/// - `riding`: Ride has started or is completing (Ride through RideDetail).
///   Cancel label is "Cancel the ride" and the ride is recorded.
enum RidePhase: Sendable {
    case none
    case ordering
    case riding

    /// The localized label for the cancel action in the menu.
    var cancelLabel: String {
        switch self {
        case .none:
            ""
        case .ordering:
            "Cancel the order"
        case .riding:
            "Cancel the ride"
        }
    }
}
