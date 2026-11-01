import Foundation

public enum SplitGeometry {
    /// True when two frames are complementary halves separated by exactly the
    /// configured gap and share the same perpendicular span.
    public static func areAdjacentHalves(
        _ firstFrame: CGRect,
        _ secondFrame: CGRect,
        firstZone: SnapZone,
        secondZone: SnapZone,
        gap: CGFloat
    ) -> Bool {
        let tolerance: CGFloat = 4

        switch (firstZone, secondZone) {
        case (.leftHalf, .rightHalf):
            return abs(firstFrame.minY - secondFrame.minY) <= tolerance
                && abs(firstFrame.height - secondFrame.height) <= tolerance
                && abs(firstFrame.maxX + gap - secondFrame.minX) <= tolerance
        case (.rightHalf, .leftHalf):
            return abs(firstFrame.minY - secondFrame.minY) <= tolerance
                && abs(firstFrame.height - secondFrame.height) <= tolerance
                && abs(secondFrame.maxX + gap - firstFrame.minX) <= tolerance
        case (.topHalf, .bottomHalf):
            return abs(firstFrame.minX - secondFrame.minX) <= tolerance
                && abs(firstFrame.width - secondFrame.width) <= tolerance
                && abs(firstFrame.minY - gap - secondFrame.maxY) <= tolerance
        case (.bottomHalf, .topHalf):
            return abs(firstFrame.minX - secondFrame.minX) <= tolerance
                && abs(firstFrame.width - secondFrame.width) <= tolerance
                && abs(secondFrame.minY - gap - firstFrame.maxY) <= tolerance
        default:
            return false
        }
    }

    public static func verticalFrames(
        first: CGRect,
        second: CGRect,
        gap: CGFloat,
        proposedBoundary: CGFloat,
        minWidth: CGFloat
    ) -> (first: CGRect, second: CGRect) {
        let minBoundary = first.minX + minWidth + gap / 2
        let maxBoundary = second.maxX - minWidth - gap / 2
        guard maxBoundary > minBoundary else { return (first, second) }

        let boundary = max(minBoundary, min(maxBoundary, proposedBoundary))
        var newFirst = first
        var newSecond = second
        newFirst.size.width = boundary - gap / 2 - first.minX
        newSecond.origin.x = boundary + gap / 2
        newSecond.size.width = second.maxX - newSecond.minX
        return (newFirst, newSecond)
    }

    public static func horizontalFrames(
        first: CGRect,
        second: CGRect,
        gap: CGFloat,
        proposedBoundary: CGFloat,
        minHeight: CGFloat
    ) -> (first: CGRect, second: CGRect) {
        let minBoundary = second.minY + minHeight + gap / 2
        let maxBoundary = first.maxY - minHeight - gap / 2
        guard maxBoundary > minBoundary else { return (first, second) }

        let boundary = max(minBoundary, min(maxBoundary, proposedBoundary))
        var newFirst = first
        var newSecond = second

        let firstY = boundary + gap / 2
        newFirst.origin.y = firstY
        newFirst.size.height = first.maxY - firstY
        newSecond.size.height = boundary - gap / 2 - second.minY
        return (newFirst, newSecond)
    }
}
