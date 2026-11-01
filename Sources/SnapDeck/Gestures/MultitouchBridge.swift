import Foundation
import SnapDeckCore
import SnapDeckMultitouch

final class MultitouchBridge {
    typealias FrameHandler = (TrackpadTouchFrame) -> Void

    private var handler: FrameHandler?

    var isRunning: Bool { SDMTIsRunning() }
    var lastError: String? {
        guard let pointer = SDMTLastError(), pointer.pointee != 0 else { return nil }
        return String(cString: pointer)
    }

    static var isAvailable: Bool { SDMTIsAvailable() }

    @discardableResult
    func start(handler: @escaping FrameHandler) -> Bool {
        self.handler = handler
        let context = Unmanaged.passUnretained(self).toOpaque()
        let started = SDMTStart(snapDeckTouchCallback, context)
        if !started {
            self.handler = nil
        }
        return started
    }

    func setMinimumContactCount(_ count: Int) {
        SDMTSetMinimumContactCount(Int32(count))
    }

    func stop() {
        SDMTStop()
        handler = nil
    }

    fileprivate func receive(_ frame: SDTouchFrame) {
        guard let handler else { return }
        handler(
            TrackpadTouchFrame(
                count: Int(frame.count),
                x: frame.x,
                y: frame.y,
                spread: frame.spread,
                timestamp: frame.timestamp
            )
        )
    }
}

private let snapDeckTouchCallback: SDTouchFrameCallback = { frame, context in
    guard let frame, let context else { return }
    let bridge = Unmanaged<MultitouchBridge>.fromOpaque(context).takeUnretainedValue()
    bridge.receive(frame.pointee)
}
