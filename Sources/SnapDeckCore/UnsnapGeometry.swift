import Foundation

/// Frame math for the Windows-style "pull a pinned window away and it becomes
/// its old size again" transition.
public enum UnsnapGeometry {
    public static func restoredFrame(
        snappedFrame: CGRect,
        originalFrame: CGRect,
        dragStart: CGPoint,
        currentPoint: CGPoint,
        visibleFrame: CGRect?
    ) -> CGRect {
        let anchorX: CGFloat
        if snappedFrame.width > 0 {
            anchorX = min(
                max((dragStart.x - snappedFrame.minX) / snappedFrame.width, 0.06),
                0.94
            )
        } else {
            anchorX = 0.5
        }

        let topOffset = min(max(snappedFrame.maxY - dragStart.y, 8), 32)
        var originX = currentPoint.x - anchorX * originalFrame.width
        var titleBarTop = currentPoint.y + topOffset

        if let visibleFrame {
            let visibleTitleWidth = min(160, originalFrame.width)
            originX = min(
                max(originX, visibleFrame.minX - originalFrame.width + visibleTitleWidth),
                visibleFrame.maxX - visibleTitleWidth
            )
            titleBarTop = min(
                max(titleBarTop, visibleFrame.minY + 40),
                visibleFrame.maxY
            )
        }

        return CGRect(
            x: originX,
            y: titleBarTop - originalFrame.height,
            width: originalFrame.width,
            height: originalFrame.height
        )
    }
}
