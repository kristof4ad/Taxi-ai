/// Describes the current phase of a ride for determining menu behavior.
///
/// - `none`: No ride in progress (Home screen). The menu offers only ride history.
/// - `ordering`: Ride is being ordered but hasn't started (RoutePreview through
///   StartRide). Cancelling is free and the ride is not recorded.
/// - `riding`: Ride has started or is completing (Ride through RideDetail).
///   Cancelling still charges the rider and the ride is recorded.
enum RidePhase: Sendable {
    case none
    case ordering
    case riding

    /// The localized label for the cancel action in the menu.
    var cancelLabel: String {
        switch self {
        case .none:
            ""
        case .ordering, .riding:
            "Cancel this ride"
        }
    }

    /// The message shown in the cancel confirmation alert.
    var cancelMessage: String {
        switch self {
        case .none:
            ""
        case .ordering:
            "You won't be charged if you cancel now."
        case .riding:
            "You will be charged for this ride."
        }
    }
}
