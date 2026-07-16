import CoreGraphics

struct ScreenSourceZoomRequest {
    let baseCrop: CGRect?
    let zoom: CGFloat
}

enum ScreenSourceZoomGeometry {
    static let minimumZoom: CGFloat = 1
    static let maximumZoom: CGFloat = 1.5

    static func crop(request: ScreenSourceZoomRequest) -> CGRect? {
        let base = normalized(request.baseCrop ?? CGRect(x: 0, y: 0, width: 1, height: 1))
        let zoom = clamped(request.zoom)
        if abs(zoom - 1) < 0.0001 {
            return isFullFrame(base) ? nil : base
        }
        let width = base.width / zoom
        let height = base.height / zoom
        let crop = normalized(CGRect(
            x: base.midX - width / 2,
            y: base.midY - height / 2,
            width: width,
            height: height
        ))
        return isFullFrame(crop) ? nil : crop
    }

    static func clamped(_ zoom: CGFloat) -> CGFloat {
        min(maximumZoom, max(minimumZoom, zoom))
    }

    private static func normalized(_ crop: CGRect) -> CGRect {
        let width = min(1, max(0.001, crop.width))
        let height = min(1, max(0.001, crop.height))
        let x = min(1 - width, max(0, crop.minX))
        let y = min(1 - height, max(0, crop.minY))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func isFullFrame(_ crop: CGRect) -> Bool {
        abs(crop.minX) < 0.0001
            && abs(crop.minY) < 0.0001
            && abs(crop.width - 1) < 0.0001
            && abs(crop.height - 1) < 0.0001
    }
}
