import MapKit
import UIKit

/// Captures a static map image with the route polyline drawn on it for ride history records.
enum MapSnapshotService {

    /// Takes a snapshot of the map showing the completed route and destination marker.
    /// - Parameters:
    ///   - route: The completed ride route.
    ///   - destination: The destination coordinate for the marker overlay.
    /// - Returns: PNG image data, or `nil` if the snapshot fails.
    static func takeSnapshot(
        route: MKRoute,
        destination: CLLocationCoordinate2D
    ) async -> Data? {
        let options = MKMapSnapshotter.Options()

        // Frame the snapshot region around the route with padding.
        let mapRect = route.polyline.boundingMapRect
        let paddedRect = mapRect.insetBy(
            dx: -mapRect.size.width * 0.3,
            dy: -mapRect.size.height * 0.3
        )
        options.region = MKCoordinateRegion(paddedRect)
        options.size = CGSize(width: 400, height: 260)
        options.scale = 2.0
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = drawRoute(on: snapshot, route: route, destination: destination, size: options.size)
            return image.pngData()
        } catch {
            return nil
        }
    }

    // MARK: - Private

    /// Draws the route polyline and a destination marker on the map snapshot.
    private static func drawRoute(
        on snapshot: MKMapSnapshotter.Snapshot,
        route: MKRoute,
        destination: CLLocationCoordinate2D,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            // Draw the base map image.
            snapshot.image.draw(at: .zero)

            // Draw route polyline.
            let path = UIBezierPath()
            let coordinates = route.coordinates

            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            UIColor.systemBlue.setStroke()
            path.lineWidth = 4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            // Draw destination marker dot.
            let destPoint = snapshot.point(for: destination)
            let markerRadius: CGFloat = 8
            let markerRect = CGRect(
                x: destPoint.x - markerRadius,
                y: destPoint.y - markerRadius,
                width: markerRadius * 2,
                height: markerRadius * 2
            )
            UIColor.black.setFill()
            UIBezierPath(ovalIn: markerRect).fill()
            UIColor.white.setStroke()
            let outline = UIBezierPath(ovalIn: markerRect)
            outline.lineWidth = 2
            outline.stroke()
        }
    }
}
