import Foundation

/// Maps a pointer position to a Windows-style snap target.
///
/// All coordinates are Cocoa screen coordinates (origin at the bottom-left).
public struct EdgeDetector: Sendable {
    public var threshold: CGFloat
    public var cornerThreshold: CGFloat
    /// The top edge needs a more generous band on macOS: the menu bar sits
    /// above the usable frame, and people naturally stop at the first visible
    /// top edge rather than pushing the pointer into the menu bar.
    public var topThreshold: CGFloat

    public init(
        threshold: CGFloat = 12,
        cornerThreshold: CGFloat = 56,
        topThreshold: CGFloat? = nil
    ) {
        self.threshold = max(2, threshold)
        self.cornerThreshold = max(12, cornerThreshold)
        self.topThreshold = max(self.threshold, topThreshold ?? self.threshold)
    }

    public func zone(for point: CGPoint, in visibleFrame: CGRect) -> SnapZone? {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }
        guard point.x >= visibleFrame.minX - threshold,
              point.x <= visibleFrame.maxX + threshold,
              point.y >= visibleFrame.minY - threshold,
              point.y <= visibleFrame.maxY + threshold
        else {
            return nil
        }

        let nearLeft = point.x <= visibleFrame.minX + threshold
        let nearRight = point.x >= visibleFrame.maxX - threshold
        let nearTop = point.y >= visibleFrame.maxY - topThreshold
        let nearBottom = point.y <= visibleFrame.minY + threshold

        // Corners win over edges, but only inside a small corner band. This
        // prevents half of the top edge from becoming a quarter by accident.
        let inHorizontalCornerBand = point.x <= visibleFrame.minX + cornerThreshold
            || point.x >= visibleFrame.maxX - cornerThreshold
        let inVerticalCornerBand = point.y <= visibleFrame.minY + cornerThreshold
            || point.y >= visibleFrame.maxY - cornerThreshold

        if nearTop && nearLeft && inHorizontalCornerBand && inVerticalCornerBand {
            return .topLeft
        }
        if nearTop && nearRight && inHorizontalCornerBand && inVerticalCornerBand {
            return .topRight
        }
        if nearBottom && nearLeft && inHorizontalCornerBand && inVerticalCornerBand {
            return .bottomLeft
        }
        if nearBottom && nearRight && inHorizontalCornerBand && inVerticalCornerBand {
            return .bottomRight
        }

        if nearTop { return .maximize }
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearBottom { return .bottomHalf }
        return nil
    }
}
