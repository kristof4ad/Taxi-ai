import SwiftUI

/// A car icon used as a map annotation, with an optional label shown below.
struct CarMarkerView: View {
    var showPickupLabel = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "car.side.fill")
                .font(.title3)
                .foregroundStyle(.black)

            if showPickupLabel {
                Text("Pickup")
                    .font(.caption2)
                    .bold()
            }
        }
    }
}
