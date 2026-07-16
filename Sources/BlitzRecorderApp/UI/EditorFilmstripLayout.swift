import CoreGraphics

struct EditorFilmstripLayout {
    private static let targetCellWidth: CGFloat = 84
    private static let minimumCellCount = 8
    private static let maximumCellCount = 192

    struct Request {
        let width: CGFloat
        let availableFrameCount: Int
    }

    let cellWidth: CGFloat
    let frameIndices: [Int]

    static func make(request: Request) -> EditorFilmstripLayout {
        let cellCount = requestedFrameCount(width: request.width)
        guard request.availableFrameCount > 0 else {
            return EditorFilmstripLayout(
                cellWidth: request.width / CGFloat(cellCount),
                frameIndices: []
            )
        }

        let lastFrameIndex = request.availableFrameCount - 1
        let frameIndices = (0..<cellCount).map { cellIndex in
            guard cellCount > 1 else { return 0 }
            let progress = Double(cellIndex) / Double(cellCount - 1)
            return min(lastFrameIndex, Int((progress * Double(lastFrameIndex)).rounded()))
        }
        return EditorFilmstripLayout(
            cellWidth: request.width / CGFloat(cellCount),
            frameIndices: frameIndices
        )
    }

    static func requestedFrameCount(width: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return minimumCellCount }
        return min(
            maximumCellCount,
            max(minimumCellCount, Int(ceil(width / targetCellWidth)))
        )
    }
}
