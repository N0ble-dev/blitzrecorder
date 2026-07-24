import CoreGraphics

enum ScreenWindowFramingPolicy {
    static let physicalWindowScale: CGFloat = 1
    static let maximumPhysicalWindowHeight: CGFloat = 720

    static func compactedPhysicalFrame(_ frame: CGRect) -> CGRect {
        guard frame.height > maximumPhysicalWindowHeight else { return frame }
        let scale = maximumPhysicalWindowHeight / frame.height
        let width = frame.width * scale
        return CGRect(
            x: frame.midX - width / 2,
            y: frame.midY - maximumPhysicalWindowHeight / 2,
            width: width,
            height: maximumPhysicalWindowHeight
        )
    }
}

enum ScreenSourceZoomGeometry {
    static let minimumZoom: CGFloat = 1
    static let maximumZoom: CGFloat = 2

    static func clamped(_ zoom: CGFloat) -> CGFloat {
        min(maximumZoom, max(minimumZoom, zoom))
    }
}
