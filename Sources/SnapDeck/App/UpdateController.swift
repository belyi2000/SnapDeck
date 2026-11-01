import AppKit
import Sparkle

/// Sparkle is started lazily: SnapDeck never checks for updates in the background.
/// The user triggers every check explicitly from the status bar menu.
@MainActor
final class UpdateController: NSObject {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.startUpdater()
        updaterController.checkForUpdates(sender)
    }
}
