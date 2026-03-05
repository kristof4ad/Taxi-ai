import MapKit
import SwiftUI

/// Shows the calculated route with trip details and pricing before booking.
struct RoutePreviewView: View {
    @Bindable var viewModel: TripViewModel
    var onBook: () -> Void
    var onBack: () -> Void
    var onCancel: () -> Void
    var onShowRideHistory: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                RouteMapSection(
                    cameraPosition: $viewModel.cameraPosition,
                    route: viewModel.route,
                    destination: viewModel.destination,
                    onBack: onBack,
                    isMenuPresented: $isMenuPresented
                )

                RouteDetailsCard(
                    viewModel: viewModel,
                    onBook: onBook
                )
            }
            .ignoresSafeArea(edges: .top)

            AppMenuOverlay(
                isPresented: $isMenuPresented,
                ridePhase: .ordering,
                onCancel: onCancel,
                onShowRideHistory: onShowRideHistory
            )
        }
    }
}

// MARK: - Map Section

private struct RouteMapSection: View {
    @Binding var cameraPosition: MapCameraPosition
    var route: MKRoute?
    var destination: CLLocationCoordinate2D?
    var onBack: () -> Void
    @Binding var isMenuPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let destination {
                    Annotation("Destination", coordinate: destination) {
                        DestinationMarkerView()
                    }
                }

                if let route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .mapStyle(.standard)
            .mapControls {}

            HStack {
                BackButton(action: onBack)
                Spacer()
                AppMenuButton(isPresented: $isMenuPresented)
            }
            .padding(.top, 62)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Back Button

private struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button("Back", systemImage: "chevron.left", action: action)
            .labelStyle(.iconOnly)
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .contentShape(.circle)
            .background(.background, in: .circle)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .buttonStyle(.plain)
    }
}

// MARK: - Route Details Card

private struct RouteDetailsCard: View {
    var viewModel: TripViewModel
    var onBook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let tripInfo = viewModel.tripInfo {
                let minutes = Int(tripInfo.expectedTravelTime / 60)
                Text("A ride can arrive in \(minutes) min")
                    .font(.headline)

                Text("Prepare to meet at the pickup spot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)

                Text("Calculating route...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 12)

            TripTimeline(viewModel: viewModel)

            Spacer()
                .frame(height: 16)

            BookButton(
                price: viewModel.estimatedPrice,
                currencyCode: viewModel.displayCurrencyCode,
                action: onBook
            )
        }
        .padding(.init(top: 20, leading: 16, bottom: 24, trailing: 16))
        .background(.background)
    }
}

// MARK: - Trip Timeline

private struct TripTimeline: View {
    var viewModel: TripViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Pickup row
            HStack(spacing: 12) {
                Circle()
                    .stroke(Color.secondary, lineWidth: 2)
                    .frame(width: 12, height: 12)

                Text("Pickup")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(viewModel.estimatedPickupTime, format: .dateTime.hour().minute())
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Connector line
            HStack {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2, height: 20)
                    .padding(.leading, 21)
                Spacer()
            }

            // Destination row
            HStack(spacing: 12) {
                Circle()
                    .fill(.primary)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.destinationName ?? "Destination")
                        .font(.subheadline.weight(.medium))

                    if let address = viewModel.destinationAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let arrivalTime = viewModel.estimatedArrivalTime {
                    Text(arrivalTime, format: .dateTime.hour().minute())
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

// MARK: - Book Button

private struct BookButton: View {
    var price: Double?
    var currencyCode: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let price {
                    Text("Book Ride \u{00B7} \(price, format: .currency(code: currencyCode))")
                } else {
                    ProgressView()
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.83, green: 0.66, blue: 0.29),
                        Color(red: 0.72, green: 0.58, blue: 0.29)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(.rect(cornerRadius: 26))
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .disabled(price == nil)
    }
}
