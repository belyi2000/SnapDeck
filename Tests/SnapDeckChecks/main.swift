import Foundation
import SnapDeckCore

var failureCount = 0
var checkCount = 0

func check(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    checkCount += 1
    if !condition() {
        failureCount += 1
        let fileURL = URL(fileURLWithPath: "\(file)")
        print("FAIL \(fileURL.lastPathComponent):\(line) — \(message)")
    }
}

func close(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
    abs(lhs - rhs) <= tolerance
}

let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

// MARK: - Snap zones

let left = SnapZone.leftHalf.rect(in: screen, gap: 10)
let right = SnapZone.rightHalf.rect(in: screen, gap: 10)
check(close(left.minX, 10), "left half starts after the gap")
check(close(right.maxX, 1430), "right half ends before the gap")
check(close(left.width, right.width), "halves have equal width")
check(close(left.maxX + 10, right.minX), "halves have an inner gap")
check(close(left.height, 880), "halves fill the usable height")

let topLeft = SnapZone.topLeft.rect(in: screen, gap: 0)
let bottomRight = SnapZone.bottomRight.rect(in: screen, gap: 0)
check(close(topLeft.minY, 450), "top-left starts at screen midpoint")
check(close(topLeft.maxY, 900), "top-left reaches the top")
check(close(bottomRight.maxY, 450), "bottom-right ends at screen midpoint")
check(close(bottomRight.minX, 720), "bottom-right starts at width midpoint")

let thirds = [
    SnapZone.firstThird.rect(in: screen, gap: 6),
    SnapZone.centerThird.rect(in: screen, gap: 6),
    SnapZone.lastThird.rect(in: screen, gap: 6)
]
check(close(thirds[0].width, thirds[1].width), "first and center thirds are equal")
check(close(thirds[1].width, thirds[2].width), "center and last thirds are equal")
check(close(thirds[0].minX, 6), "first third honors the gap")
check(close(thirds[2].maxX, 1434), "last third honors the gap")

let maximized = SnapZone.maximize.rect(in: screen, gap: 8)
check(maximized == CGRect(x: 8, y: 8, width: 1424, height: 884), "maximize honors the gap")

let center = SnapZone.center.rect(in: screen, gap: 0)
check(close(center.midX, screen.midX), "center is horizontally centered")
check(close(center.midY, screen.midY), "center is vertically centered")
check(center.width < screen.width, "center does not fill the width")

let veryLargeGap = SnapZone.leftHalf.rect(in: screen, gap: 10_000)
check(veryLargeGap.width > 0, "absurdly large gap is clamped safely")

// MARK: - Coordinates and screens

let ax = CGRect(x: 100, y: 80, width: 500, height: 300)
let cocoa = ScreenGeometry.cocoaRect(fromAX: ax, primaryHeight: 900)
check(cocoa == CGRect(x: 100, y: 520, width: 500, height: 300), "AX to Cocoa conversion")
check(ScreenGeometry.axRect(fromCocoa: cocoa, primaryHeight: 900) == ax, "Cocoa to AX round-trip")

let screens = [
    CGRect(x: 0, y: 0, width: 1440, height: 900),
    CGRect(x: 1440, y: 0, width: 1920, height: 1080)
]
let overlappingWindow = CGRect(x: 1200, y: 100, width: 600, height: 500)
check(
    ScreenGeometry.screenIndex(withLargestIntersection: overlappingWindow, in: screens) == 1,
    "screen selection uses the largest overlap"
)
check(
    ScreenGeometry.screenIndex(containing: CGPoint(x: 1600, y: 500), in: screens) == 1,
    "screen selection uses the containing screen"
)
check(
    ScreenGeometry.screenIndex(containing: CGPoint(x: 1500, y: 500), in: screens) != nil,
    "a point on a shared edge belongs to a screen"
)

let mapped = ScreenGeometry.mappedRect(
    CGRect(x: 720, y: 0, width: 720, height: 900),
    from: CGRect(x: 0, y: 0, width: 1440, height: 900),
    to: CGRect(x: 1440, y: 0, width: 1920, height: 1080)
)
check(close(mapped.width, 960), "mapped window keeps relative width")
check(close(mapped.height, 1080), "mapped window is clamped to the display height")
check(mapped.maxX <= 3360, "mapped window stays inside the target display")

// MARK: - Edge detector

let detector = EdgeDetector(threshold: 10, cornerThreshold: 60)
check(detector.zone(for: CGPoint(x: 500, y: 2), in: screen) == .bottomHalf, "bottom edge")
check(detector.zone(for: CGPoint(x: 3, y: 400), in: screen) == .leftHalf, "left edge")
check(detector.zone(for: CGPoint(x: 1437, y: 400), in: screen) == .rightHalf, "right edge")
check(detector.zone(for: CGPoint(x: 700, y: 898), in: screen) == .maximize, "top edge")
check(detector.zone(for: CGPoint(x: 2, y: 898), in: screen) == .topLeft, "top-left corner")
check(detector.zone(for: CGPoint(x: 1438, y: 898), in: screen) == .topRight, "top-right corner")
check(detector.zone(for: CGPoint(x: 2, y: 2), in: screen) == .bottomLeft, "bottom-left corner")
check(detector.zone(for: CGPoint(x: 1438, y: 2), in: screen) == .bottomRight, "bottom-right corner")
check(detector.zone(for: CGPoint(x: 720, y: 899), in: screen) == .maximize, "top middle is maximize")
check(detector.zone(for: CGPoint(x: 720, y: 450), in: screen) == nil, "center does not snap")
check(detector.zone(for: CGPoint(x: 2000, y: 450), in: screen) == nil, "outside does not snap")
check(detector.zone(for: CGPoint(x: 100, y: 898), in: screen) == .maximize, "top edge away from corner")
check(detector.zone(for: CGPoint(x: 100, y: 700), in: screen) == nil, "one axis is not enough")

let physicalScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
let usableScreen = CGRect(x: 0, y: 0, width: 1440, height: 875)
let topFrame = ScreenGeometry.edgeDetectionFrame(
    screenFrame: physicalScreen,
    visibleFrame: usableScreen
)
let topDetector = EdgeDetector(threshold: 11, cornerThreshold: 58, topThreshold: 28)
check(topFrame.maxY == 875, "top detection uses the visible top edge")
check(
    topDetector.zone(for: CGPoint(x: 720, y: 850), in: topFrame) == .maximize,
    "top edge snaps below the menu bar"
)
check(
    topDetector.zone(for: CGPoint(x: 720, y: 820), in: topFrame) == nil,
    "top band does not swallow the whole screen"
)

check(SnapZone.leftHalf.assistZone == .rightHalf, "left half offers right half")
check(SnapZone.topRight.assistZone == .leftHalf, "top-right offers left half")
check(SnapZone.firstThird.assistZone == nil, "thirds do not show assist")
check(SnapZone.leftHalf.complementaryHalf == .rightHalf, "left complements right")
check(SnapZone.bottomHalf.complementaryHalf == .topHalf, "bottom complements top")
check(SnapZone.topLeft.complementaryHalf == nil, "corners do not form a linked half group")

let leftHalfFrame = CGRect(x: 0, y: 0, width: 700, height: 900)
let rightHalfFrame = CGRect(x: 706, y: 0, width: 700, height: 900)
check(
    SplitGeometry.areAdjacentHalves(
        leftHalfFrame,
        rightHalfFrame,
        firstZone: .leftHalf,
        secondZone: .rightHalf,
        gap: 6
    ),
    "adjacent half frames are detected"
)
check(
    !SplitGeometry.areAdjacentHalves(
        leftHalfFrame,
        CGRect(x: 800, y: 0, width: 700, height: 900),
        firstZone: .leftHalf,
        secondZone: .rightHalf,
        gap: 6
    ),
    "separated frames are not treated as a group"
)

let splitLeft = CGRect(x: 0, y: 0, width: 700, height: 900)
let splitRight = CGRect(x: 706, y: 0, width: 700, height: 900)
let resizedVertical = SplitGeometry.verticalFrames(
    first: splitLeft,
    second: splitRight,
    gap: 6,
    proposedBoundary: 800,
    minWidth: 200
)
check(close(resizedVertical.first.maxX + 3, 800), "vertical split boundary moves")
check(close(resizedVertical.second.minX - 3, 800), "vertical split keeps the gap")
check(close(resizedVertical.first.minX, 0), "vertical split keeps the left edge")
check(close(resizedVertical.second.maxX, 1406), "vertical split keeps the right edge")
check(close(resizedVertical.first.height, 900), "vertical split keeps heights")

let clampedVertical = SplitGeometry.verticalFrames(
    first: splitLeft,
    second: splitRight,
    gap: 6,
    proposedBoundary: 10,
    minWidth: 200
)
check(clampedVertical.first.width >= 200, "vertical split enforces minimum width")

let topHalfFrame = CGRect(x: 0, y: 456, width: 1400, height: 450)
let bottomHalfFrame = CGRect(x: 0, y: 0, width: 1400, height: 450)
let resizedHorizontal = SplitGeometry.horizontalFrames(
    first: topHalfFrame,
    second: bottomHalfFrame,
    gap: 6,
    proposedBoundary: 550,
    minHeight: 140
)
check(close(resizedHorizontal.first.minY - 3, 550), "horizontal split boundary moves")
check(close(resizedHorizontal.second.maxY + 3, 550), "horizontal split keeps the gap")
check(close(resizedHorizontal.first.maxY, 906), "horizontal split keeps the top edge")
check(close(resizedHorizontal.second.minY, 0), "horizontal split keeps the bottom edge")

// MARK: - Tiling presets

let tilingScreen = CGRect(x: 0, y: 0, width: 1200, height: 800)
let twoColumns = TilingPreset.twoColumns.frames(count: 2, in: tilingScreen, gap: 0)
check(twoColumns == [
    CGRect(x: 0, y: 0, width: 600, height: 800),
    CGRect(x: 600, y: 0, width: 600, height: 800)
], "two-column preset")

let balanced = TilingPreset.twoColumns.frames(count: 3, in: tilingScreen, gap: 8)
check(balanced.count == 3, "balanced preset returns one frame per window")
check(close(balanced[0].width, balanced[1].width), "balanced preset equal column widths")
check(close(balanced[2].height, 784), "balanced preset fills column height")

let grid = TilingPreset.grid.frames(count: 4, in: tilingScreen, gap: 0)
check(grid.count == 4, "grid preset returns four frames")
check(close(grid[0].width, 600), "grid cell width")
check(close(grid[0].height, 400), "grid cell height")
check(grid[3].origin == CGPoint(x: 600, y: 0), "grid bottom-right origin")

let mainLeft = TilingPreset.mainLeftStack.frames(count: 3, in: tilingScreen, gap: 10)
check(mainLeft.count == 3, "main-left returns three frames")
check(close(mainLeft[0].height, 780), "main window fills height")
check(mainLeft[0].width > mainLeft[1].width, "main window is wider than stack")

let mainTop = TilingPreset.mainTopRow.frames(count: 3, in: tilingScreen, gap: 10)
check(mainTop.count == 3, "main-top returns three frames")
check(mainTop[0].maxY == 790, "main-top touches the top gap")
check(mainTop[0].width > mainTop[1].width, "main-top spans the row")

let cascade = TilingPreset.cascade.frames(count: 12, in: tilingScreen, gap: 0)
check(cascade.count == 12, "cascade returns one frame per window")
for frame in cascade {
    check(frame.width > 0 && frame.height > 0, "cascade frame has positive size")
    check(frame.minX >= 0 && frame.minY >= 0, "cascade frame starts inside")
    check(frame.maxX <= 1200.001 && frame.maxY <= 800.001, "cascade frame ends inside")
}

// MARK: - Unsnap geometry

let maximizedForUnsnap = CGRect(x: 0, y: 0, width: 1440, height: 900)
let originalForUnsnap = CGRect(x: 300, y: 200, width: 800, height: 600)
let restored = UnsnapGeometry.restoredFrame(
    snappedFrame: maximizedForUnsnap,
    originalFrame: originalForUnsnap,
    dragStart: CGPoint(x: 720, y: 890),
    currentPoint: CGPoint(x: 720, y: 800),
    visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
)
check(close(restored.width, 800), "unsnap restores the original width")
check(close(restored.height, 600), "unsnap restores the original height")
check(close(restored.midX, 720), "unsnap keeps the grab point under the cursor")
check(restored.maxY <= 875, "unsnap keeps the title bar on screen")

let snappedLeft = CGRect(x: 0, y: 0, width: 720, height: 900)
let restoredLeft = UnsnapGeometry.restoredFrame(
    snappedFrame: snappedLeft,
    originalFrame: originalForUnsnap,
    dragStart: CGPoint(x: 360, y: 890),
    currentPoint: CGPoint(x: 700, y: 700),
    visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
)
check(close(restoredLeft.midX, 700), "unsnap anchors a half-window under the cursor")
check(close(restoredLeft.width, 800), "unsnap preserves the pre-snap size")

let clampLeft = UnsnapGeometry.restoredFrame(
    snappedFrame: snappedLeft,
    originalFrame: originalForUnsnap,
    dragStart: CGPoint(x: 360, y: 890),
    currentPoint: CGPoint(x: 2, y: 700),
    visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
)
check(clampLeft.maxX >= 160, "unsnap keeps part of the title bar reachable")

// MARK: - Trackpad swipe recognizer

func runRecognizer(
    _ frames: [(Int, Float, Float, Float)],
    configure: (inout TrackpadSwipeRecognizer) -> Void = { _ in }
) -> (actions: [TrackpadWindowAction], recognizer: TrackpadSwipeRecognizer) {
    var recognizer = TrackpadSwipeRecognizer(sensitivity: 1.0)
    configure(&recognizer)
    var actions: [TrackpadWindowAction] = []
    for (index, point) in frames.enumerated() {
        let frame = TrackpadTouchFrame(
            count: point.0,
            x: point.1,
            y: point.2,
            spread: point.3,
            timestamp: Double(index) * 0.016
        )
        if let action = recognizer.process(frame) {
            actions.append(action)
        }
    }
    return (actions, recognizer)
}

func recognize(
    _ frames: [(Int, Float, Float, Float)],
    configure: (inout TrackpadSwipeRecognizer) -> Void = { _ in }
) -> [TrackpadWindowAction] {
    runRecognizer(frames, configure: configure).actions
}

let startThree: (Int, Float, Float, Float) = (3, 0.50, 0.50, 0.20)
let startFour: (Int, Float, Float, Float) = (4, 0.50, 0.50, 0.28)

check(recognize([startThree, (3, 0.42, 0.50, 0.20)]) == [.snapLeft], "3-finger left snaps left")
check(recognize([startThree, (3, 0.58, 0.50, 0.20)]) == [.snapRight], "3-finger right snaps right")
check(recognize([startThree, (3, 0.50, 0.58, 0.20)]) == [.maximize], "3-finger up maximizes")
check(recognize([startThree, (3, 0.50, 0.42, 0.20)]) == [.minimizeFocused], "3-finger down minimizes one window")
check(recognize([startFour, (4, 0.50, 0.42, 0.28)]) == [.minimizeAll], "4-finger down minimizes all windows")
check(recognize([startFour, (4, 0.50, 0.58, 0.28)]) == [.restoreAll], "4-finger up restores all windows")
check(recognize([startFour, (4, 0.58, 0.50, 0.28)]).isEmpty, "short 4-finger right is reserved")
check(recognize([startFour, (4, 0.72, 0.50, 0.28)]) == [.closeApplication], "long 4-finger right closes the app")
check(
    recognize([startFour, (4, 0.58, 0.50, 0.28), (4, 0.72, 0.50, 0.28)]) == [.closeApplication],
    "short 4-finger right can continue into the long close swipe"
)
check(recognize([startFour, (4, 0.42, 0.50, 0.28)]).isEmpty, "4-finger left is unassigned")
check(recognize([startThree, (3, 0.50, 0.42, 0.42)]).isEmpty, "pinch-like spread changes are ignored")
check(recognize([startThree, (3, 0.44, 0.44, 0.20)]).isEmpty, "ambiguous diagonal is ignored")
check(recognize([startThree, (3, 0.42, 0.50, 0.20), (3, 0.38, 0.50, 0.20)]) == [.snapLeft], "one action per touch session")
check(
    recognize([startThree, (4, 0.50, 0.50, 0.28), (4, 0.50, 0.42, 0.28)]) == [.minimizeAll],
    "3-to-4 finger handoff can minimize all"
)
check(
    recognize([startThree, (3, 0.42, 0.50, 0.20), (0, 0.0, 0.0, 0.0), startThree, (3, 0.58, 0.50, 0.20)])
        == [.snapLeft, .snapRight],
    "lift resets the recognizer"
)
check(
    recognize([startThree, (3, 0.42, 0.50, 0.20), (3, 0.38, 0.50, 0.20)]).count == 1,
    "recognizer does not repeat after firing"
)

// MARK: - Two-finger close and adjustable distance

let startTwo: (Int, Float, Float, Float) = (2, 0.50, 0.50, 0.14)
let twoFingerClose: (inout TrackpadSwipeRecognizer) -> Void = { recognizer in
    recognizer.closeApplicationEnabled = true
    recognizer.twoFingerCloseEnabled = true
    recognizer.longCloseDistance = 0.20
}

check(
    recognize([startTwo, (2, 0.72, 0.50, 0.14)], configure: twoFingerClose) == [.closeApplication],
    "long 2-finger right closes the app when enabled"
)
check(
    recognize([startTwo, (2, 0.62, 0.50, 0.14)]).isEmpty,
    "short 2-finger right is reserved by default"
)
check(
    recognize(
        [startTwo, (2, 0.62, 0.50, 0.14)],
        configure: { recognizer in
            twoFingerClose(&recognizer)
            recognizer.longCloseDistance = 0.10
        }
    ) == [.closeApplication],
    "a shorter close distance makes a shorter 2-finger swipe close"
)
check(
    recognize(
        [startTwo, (2, 0.72, 0.50, 0.14)],
        configure: { recognizer in
            twoFingerClose(&recognizer)
            recognizer.longCloseDistance = 0.40
        }
    ).isEmpty,
    "a longer close distance rejects a 2-finger swipe that is too short"
)
check(
    recognize([startTwo, (2, 0.72, 0.50, 0.14)]).isEmpty,
    "2-finger close stays off until explicitly enabled"
)
check(
    recognize(
        [startTwo, (2, 0.72, 0.50, 0.14)],
        configure: { recognizer in
            twoFingerClose(&recognizer)
            recognizer.closeApplicationEnabled = false
        }
    ).isEmpty,
    "disabling close also disables the 2-finger variant"
)
check(
    recognize(
        [startFour, (4, 0.72, 0.50, 0.28)],
        configure: { recognizer in recognizer.closeApplicationEnabled = false }
    ).isEmpty,
    "disabling close disables the 4-finger variant"
)
check(
    recognize(
        [startFour, (4, 0.72, 0.50, 0.28)],
        configure: { recognizer in recognizer.longCloseDistance = 0.40 }
    ).isEmpty,
    "the shared close distance also applies to 4 fingers"
)

let afterThreeFinger = runRecognizer(
    [
        startThree,
        (3, 0.50, 0.58, 0.20),
        (2, 0.60, 0.50, 0.14),
        (2, 0.76, 0.50, 0.14)
    ],
    configure: twoFingerClose
)
check(
    afterThreeFinger.actions == [.maximize],
    "two fingers left after a 3-finger gesture do not close the app"
)
check(
    recognize(
        [
            startThree,
            (3, 0.50, 0.58, 0.20),
            (0, 0, 0, 0),
            startTwo,
            (2, 0.74, 0.50, 0.14)
        ],
        configure: twoFingerClose
    ) == [.maximize, .closeApplication],
    "a fresh 2-finger session after a full lift can still close"
)
check(
    recognize(
        [
            startThree,
            (3, 0.50, 0.58, 0.20),
            (2, 0.60, 0.50, 0.14),
            (1, 0.60, 0.50, 0.14),
            startTwo,
            (2, 0.76, 0.50, 0.14)
        ],
        configure: twoFingerClose
    ) == [.maximize],
    "the 2-finger close lock survives while one finger remains on the pad"
)
check(
    recognize(
        [
            startThree,
            (3, 0.50, 0.58, 0.20),
            (2, 0.60, 0.50, 0.14),
            (1, 0.60, 0.50, 0.14),
            (0, 0, 0, 0),
            startTwo,
            (2, 0.76, 0.50, 0.14)
        ],
        configure: twoFingerClose
    ) == [.maximize, .closeApplication],
    "the 2-finger close lock clears only after the pad is fully empty"
)
check(
    recognize(
        [startTwo, (2, 0.56, 0.50, 0.14), (2, 0.60, 0.50, 0.14)],
        configure: twoFingerClose
    ).isEmpty,
    "2-finger right does not fire before the close distance"
)

var suppressionRecognizer = TrackpadSwipeRecognizer(sensitivity: 1.0)
twoFingerClose(&suppressionRecognizer)
_ = suppressionRecognizer.process(
    TrackpadTouchFrame(count: 2, x: 0.50, y: 0.50, spread: 0.14, timestamp: 0)
)
_ = suppressionRecognizer.process(
    TrackpadTouchFrame(count: 2, x: 0.60, y: 0.50, spread: 0.14, timestamp: 0.016)
)
check(
    suppressionRecognizer.suppressTwoFingerScroll,
    "2-finger scroll is suppressed only after a right close candidate appears"
)
_ = suppressionRecognizer.process(
    TrackpadTouchFrame(count: 0, x: 0, y: 0, spread: 0, timestamp: 0.032)
)
check(
    !suppressionRecognizer.suppressTwoFingerScroll,
    "2-finger suppression ends on lift"
)

var noSuppression = TrackpadSwipeRecognizer(sensitivity: 1.0)
twoFingerClose(&noSuppression)
_ = noSuppression.process(
    TrackpadTouchFrame(count: 2, x: 0.50, y: 0.50, spread: 0.14, timestamp: 0)
)
_ = noSuppression.process(
    TrackpadTouchFrame(count: 2, x: 0.50, y: 0.40, spread: 0.14, timestamp: 0.016)
)
check(
    !noSuppression.suppressTwoFingerScroll,
    "2-finger vertical scroll is not suppressed"
)

// MARK: - LaunchAgent plist

let agent = LaunchAtLoginManager.agentPropertyList(
    applicationPath: "/Applications/SnapDeck.app"
)
check(
    agent["Label"] as? String == "com.dmitry.snapdeck.login",
    "login agent uses the SnapDeck label"
)
check(
    (agent["ProgramArguments"] as? [String])
        == ["/usr/bin/open", "-a", "/Applications/SnapDeck.app"],
    "login agent opens the exact app bundle"
)
check(agent["RunAtLoad"] as? Bool == true, "login agent starts at login")
check(
    agent["LimitLoadToSessionType"] as? String == "Aqua",
    "login agent is limited to the user GUI session"
)
check(
    (try? PropertyListSerialization.data(
        fromPropertyList: agent,
        format: .xml,
        options: 0
    )) != nil,
    "login agent plist serializes"
)

// MARK: - Frame history

let history = WindowFrameHistory()
let first = CGRect(x: 10, y: 10, width: 500, height: 400)
let second = CGRect(x: 20, y: 20, width: 600, height: 500)
history.record(first, for: "window")
history.record(second, for: "window")
check(history.popFrame(for: "window") == second, "history pops the most recent frame")
check(history.popFrame(for: "window") == first, "history pops the older frame")
check(history.popFrame(for: "window") == nil, "history becomes empty")

// MARK: - Result

if failureCount == 0 {
    print("SnapDeckChecks: \(checkCount) checks passed")
    exit(0)
} else {
    print("SnapDeckChecks: \(failureCount) of \(checkCount) checks failed")
    exit(1)
}
