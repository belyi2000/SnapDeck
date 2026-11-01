import AppKit
import CoreGraphics
import ScreenCaptureKit

public final class WindowThumbnailService {
    public enum Result {
        case success([String: NSImage])
        case permissionDenied
        case failed(String)
    }

    public static let shared = WindowThumbnailService()

    private let queue = DispatchQueue(label: "com.dmitry.snapdeck.thumbnails", qos: .userInitiated)

    public init() {}

    public var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Captures lightweight window thumbnails with ScreenCaptureKit. The panel
    /// is shown immediately with app icons and is then updated when images are
    /// ready; the assist UI never waits for Screen Recording.
    public func requestThumbnails(
        for windows: [WindowInfo],
        completion: @escaping (Result) -> Void
    ) {
        guard CGPreflightScreenCaptureAccess() else {
            DispatchQueue.main.async { completion(.permissionDenied) }
            return
        }

        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let requests = windows.prefix(6).map { window in
            ThumbnailRequest(
                id: window.id,
                pid: window.pid,
                frameAX: ScreenGeometry.axRect(
                    fromCocoa: window.frame,
                    primaryHeight: primaryHeight
                ),
                frameCocoa: window.frame,
                title: window.title
            )
        }

        queue.async {
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(
                        false,
                        onScreenWindowsOnly: true
                    )
                    let windowsByPID = Dictionary(grouping: content.windows) {
                        $0.owningApplication?.processID ?? 0
                    }

                    var images: [String: CGImage] = [:]
                    for request in requests {
                        guard let match = Self.bestMatch(
                            for: request,
                            in: windowsByPID[request.pid] ?? []
                        ) else {
                            continue
                        }

                        let configuration = SCStreamConfiguration()
                        let aspectRatio = match.frame.width > 0
                            ? match.frame.height / match.frame.width
                            : 0.625
                        let width = max(360, min(1080, Int(match.frame.width * 2)))
                        let height = max(200, min(760, Int(CGFloat(width) * aspectRatio)))
                        configuration.width = width
                        configuration.height = height
                        configuration.showsCursor = false
                        configuration.ignoreShadowsSingleWindow = true
                        configuration.captureResolution = .best

                        let filter = SCContentFilter(desktopIndependentWindow: match)
                        if let image = try? await SCScreenshotManager.captureImage(
                            contentFilter: filter,
                            configuration: configuration
                        ) {
                            images[request.id] = image
                        }
                    }

                    let capturedImages = images
                    await MainActor.run {
                        let converted = capturedImages.mapValues { image in
                            NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                        }
                        completion(.success(converted))
                    }
                } catch {
                    let message = error.localizedDescription
                    await MainActor.run {
                        completion(.failed(message))
                    }
                }
            }
        }
    }

    private struct ThumbnailRequest {
        let id: String
        let pid: pid_t
        let frameAX: CGRect
        let frameCocoa: CGRect
        let title: String
    }

    private static func bestMatch(
        for request: ThumbnailRequest,
        in windows: [SCWindow]
    ) -> SCWindow? {
        let candidates = windows.filter {
            $0.windowLayer == 0
                && $0.isOnScreen
                && $0.frame.width > 80
                && $0.frame.height > 60
        }

        let trimmedTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            let titleMatches = candidates.filter {
                ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == trimmedTitle
            }
            if titleMatches.count == 1 {
                return titleMatches[0]
            }
        }

        if candidates.count == 1 {
            return candidates[0]
        }

        var bestScore = CGFloat.greatestFiniteMagnitude
        var best: SCWindow?

        for window in candidates {
            // ScreenCaptureKit documents frame as screen coordinates. Depending
            // on the macOS build that can be top-left or AppKit bottom-left, so
            // accept the smaller geometric error of both interpretations.
            let scoreAX = geometryScore(window.frame, request.frameAX)
            let scoreCocoa = geometryScore(window.frame, request.frameCocoa)
            let score = min(scoreAX, scoreCocoa)

            if score < bestScore {
                bestScore = score
                best = window
            }
        }

        return bestScore < 160 ? best : nil
    }

    private static func geometryScore(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        abs(lhs.minX - rhs.minX)
            + abs(lhs.minY - rhs.minY)
            + abs(lhs.width - rhs.width)
            + abs(lhs.height - rhs.height)
    }
}
