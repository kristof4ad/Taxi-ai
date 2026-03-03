import SwiftUI

/// A car icon used as a map annotation.
struct CarMarkerView: View {
    var body: some View {
        Image(systemName: "car.side.fill")
            .font(.title3)
            .foregroundStyle(.white)
    }
}
