import AppKit
import CoreGraphics
import SnapDeckCore

struct AssistCandidate: Identifiable {
    let window: WindowInfo
    var id: String { window.id }
}

@MainActor
final class SnapAssistModel: ObservableObject {
    let candidates: [AssistCandidate]

    @Published private(set) var thumbnails: [String: NSImage] = [:]
    @Published private(set) var isLoading: Bool
    @Published private(set) var permissionDenied: Bool
    @Published private(set) var errorMessage: String?

    init(candidates: [WindowInfo]) {
        self.candidates = candidates.map(AssistCandidate.init)
        let hasPermission = CGPreflightScreenCaptureAccess()
        permissionDenied = !hasPermission
        isLoading = hasPermission
    }

    func apply(_ result: WindowThumbnailService.Result) {
        isLoading = false
        switch result {
        case let .success(images):
            thumbnails = images
            permissionDenied = false
            errorMessage = nil
        case .permissionDenied:
            permissionDenied = true
            errorMessage = nil
        case let .failed(message):
            errorMessage = message
            permissionDenied = false
        }
    }

    var hasAnyThumbnail: Bool {
        !thumbnails.isEmpty
    }
}
