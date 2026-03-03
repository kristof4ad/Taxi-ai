import SwiftUI

/// A blue dot representing the simulated taxi moving along the route.
struct SimulationDotView: View {
    var body: some View {
        Circle()
            .fill(.blue)
            .frame(width: 16, height: 16)
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 2)
            }
            .shadow(radius: 3)
    }
}
