import MapKit

extension MKRoute {
    /// Extracts all coordinate points from the route's polyline.
    var coordinates: [CLLocationCoordinate2D] {
        let pointCount = polyline.pointCount
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
