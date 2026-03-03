import SwiftUI

/// A red map pin used to mark the selected destination on the map.
struct DestinationMarkerView: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title)
            .foregroundStyle(.red)
    }
}
