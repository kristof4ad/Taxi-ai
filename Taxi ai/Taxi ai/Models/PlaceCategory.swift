import MapKit

/// Categories of nearby points of interest shown on the Home screen.
enum PlaceCategory: String, CaseIterable, Identifiable, Sendable {
    case bars
    case food
    case fast
    case fun
    case shopping

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bars: "Bars"
        case .food: "Food"
        case .fast: "Fast Food"
        case .fun: "Fun"
        case .shopping: "Shopping"
        }
    }

    var systemImage: String {
        switch self {
        case .bars: "wineglass"
        case .food: "fork.knife"
        case .fast: "list.bullet"
        case .fun: "tv"
        case .shopping: "bag"
        }
    }

    /// The MapKit point-of-interest category used for local search.
    var searchQuery: String {
        switch self {
        case .bars: "bar"
        case .food: "restaurant"
        case .fast: "fast food"
        case .fun: "entertainment"
        case .shopping: "shopping"
        }
    }
}
