import Foundation

public enum ScreenGeometry {
    public static func cocoaPoint(fromAX point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public static func axPoint(fromCocoa point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public static func cocoaRect(fromAX rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func axRect(fromCocoa rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func screenIndex(containing point: CGPoint, in frames: [CGRect]) -> Int? {
        if let exact = frames.firstIndex(where: { contains($0, point: point) }) {
            return exact
        }

        // A drag can temporarily leave every display (for example when a
        // window is thrown quickly between monitors). Pick the closest screen
        // instead of dropping the snap preview.
        var bestIndex: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, frame) in frames.enumerated() {
            let dx = max(max(frame.minX - point.x, 0), point.x - frame.maxX)
            let dy = max(max(frame.minY - point.y, 0), point.y - frame.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    public static func screenIndex(withLargestIntersection rect: CGRect, in frames: [CGRect]) -> Int? {
        var bestIndex: Int?
        var bestArea: CGFloat = 0
        for (index, frame) in frames.enumerated() {
            let intersection = frame.intersection(rect)
            guard !intersection.isNull else { continue }
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestIndex = index
            }
        }
        if bestIndex != nil { return bestIndex }
        return screenIndex(containing: CGPoint(x: rect.midX, y: rect.midY), in: frames)
    }

    public static func contains(_ rect: CGRect, point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX
            && point.y >= rect.minY && point.y <= rect.maxY
    }

    /// Edge detection uses the physical screen for left/right/bottom, but the
    /// visible frame for the top edge. On a Mac the menu bar sits above the
    /// usable top edge, and users stop at the first visible horizontal line.
    public static func edgeDetectionFrame(
        screenFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: max(1, visibleFrame.maxY - screenFrame.minY)
        )
    }

    /// The rect of a window after moving it to another display while keeping
    /// its relative position and size.
    public static func mappedRect(
        _ rect: CGRect,
        from sourceVisibleFrame: CGRect,
        to targetVisibleFrame: CGRect
    ) -> CGRect {
        guard sourceVisibleFrame.width > 0, sourceVisibleFrame.height > 0 else {
            return rect
        }

        let relativeX = (rect.minX - sourceVisibleFrame.minX) / sourceVisibleFrame.width
        let relativeY = (rect.minY - sourceVisibleFrame.minY) / sourceVisibleFrame.height
        let widthRatio = rect.width / sourceVisibleFrame.width
        let heightRatio = rect.height / sourceVisibleFrame.height

        let width = min(targetVisibleFrame.width, max(120, targetVisibleFrame.width * widthRatio))
        let height = min(targetVisibleFrame.height, max(80, targetVisibleFrame.height * heightRatio))
        let x = targetVisibleFrame.minX + relativeX * targetVisibleFrame.width
        let y = targetVisibleFrame.minY + relativeY * targetVisibleFrame.height

        return CGRect(
            x: min(max(targetVisibleFrame.minX, x), targetVisibleFrame.maxX - width),
            y: min(max(targetVisibleFrame.minY, y), targetVisibleFrame.maxY - height),
            width: width,
            height: height
        )
    }
}
