import AppKit
import SnapDeckCore
import SwiftUI

@MainActor
final class SnapAssistController {
    private var panel: SnapAssistPanel?
    private var onSelect: ((WindowInfo) -> Void)?
    private var dismissTimer: Timer?
    private var keyMonitor: Any?
    private var generation = 0

    var isVisible: Bool { panel?.isVisible == true }

    func present(
        in freeZone: CGRect,
        on screen: NSScreen,
        candidates: [WindowInfo],
        onSelect: @escaping (WindowInfo) -> Void
    ) {
        dismiss()

        guard !candidates.isEmpty,
              let panelFrame = panelFrame(
                in: freeZone,
                on: screen,
                candidateCount: min(candidates.count, 6)
              )
        else {
            return
        }

        generation += 1
        let currentGeneration = generation
        self.onSelect = onSelect

        let model = SnapAssistModel(candidates: Array(candidates.prefix(6)))
        let view = SnapAssistView(
            model: model,
            onSelect: { [weak self] window in
                guard let self else { return }
                let handler = self.onSelect
                self.dismiss()
                handler?(window)
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = NSHostingView(rootView: view)
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.autoresizingMask = [.width, .height]

        let panel = ensurePanel()
        panel.contentView = hosting
        panel.setFrame(panelFrame, display: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }

        WindowThumbnailService.shared.requestThumbnails(for: model.candidates.map(\.window)) { [weak model] result in
            model?.apply(result)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak model] event in
            guard let self else { return event }

            if event.keyCode == 53 { // Escape
                self.dismiss()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isEmpty,
               let characters = event.charactersIgnoringModifiers,
               let number = Int(characters),
               number >= 1,
               number <= (model?.candidates.count ?? 0),
               let window = model?.candidates[number - 1].window {
                let handler = self.onSelect
                self.dismiss()
                handler?(window)
                return nil
            }

            return event
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == currentGeneration else { return }
                self.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        onSelect = nil
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
    }

    func dismissIfClickOutside(_ cocoaPoint: CGPoint) {
        guard let panel, panel.isVisible else { return }
        if !ScreenGeometry.contains(panel.frame, point: cocoaPoint) {
            dismiss()
        }
    }

    /// Keep the picker as a centered glass card inside the empty half instead
    /// of stretching it edge-to-edge.
    private func panelFrame(
        in freeZone: CGRect,
        on screen: NSScreen,
        candidateCount: Int
    ) -> CGRect? {
        let margin: CGFloat = 16
        let availableWidth = freeZone.width - margin * 2
        let availableHeight = freeZone.height - margin * 2
        guard availableWidth >= 280, availableHeight >= 240 else { return nil }

        let preferredWidth: CGFloat = candidateCount == 1 ? 540 : 720
        let width = min(preferredWidth, availableWidth)
        let columns = candidateCount == 1
            ? 1
            : ((width - 28) >= 540 ? 2 : 1)
        let spacing: CGFloat = 12
        let cardWidth = (width - 28 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let cardHeight = cardWidth / 1.6 + 44
        let rows = ceil(Double(candidateCount) / Double(columns))
        let desiredHeight = 72 + 38 + 28
            + CGFloat(rows) * cardHeight
            + CGFloat(max(0, rows - 1)) * spacing
        let height = min(availableHeight, max(280, desiredHeight))

        let frame = CGRect(
            x: freeZone.midX - width / 2,
            y: freeZone.midY - height / 2,
            width: width,
            height: height
        )
        return frame.intersection(screen.visibleFrame)
    }

    private func ensurePanel() -> SnapAssistPanel {
        if let panel { return panel }

        let panel = SnapAssistPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        self.panel = panel
        return panel
    }
}

private final class SnapAssistPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
