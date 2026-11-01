import AppKit
import SnapDeckCore
import SwiftUI

@MainActor
final class SnapPreviewController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<ZonePreviewView>?
    private var currentFrame: CGRect = .zero
    private var currentZone: SnapZone?

    func show(zone: SnapZone, frame: CGRect, on screen: NSScreen) {
        guard frame.width > 2, frame.height > 2 else { return }

        let panel = ensurePanel()
        if currentZone != zone {
            let view = ZonePreviewView(zone: zone)
            if let hostingView {
                hostingView.rootView = view
            } else {
                let hosting = NSHostingView(rootView: view)
                hosting.layer?.backgroundColor = NSColor.clear.cgColor
                panel.contentView = hosting
                hostingView = hosting
            }
            currentZone = zone
        }

        if currentFrame != frame || !panel.isVisible {
            currentFrame = frame
            panel.setFrame(frame, display: true)
        }

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.09
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard let panel else { return }
        currentZone = nil
        currentFrame = .zero
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = PassthroughPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        self.panel = panel
        return panel
    }
}

private final class PassthroughPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
