import Carbon
import Foundation

public final class HotKeyManager {
    public var onAction: ((WindowCommand) -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var commandByID: [UInt32: WindowCommand] = [:]

    private static let signature: OSType = 0x534E5044 // "SNPD"
    private static let baseModifiers = UInt32(controlKey | optionKey)

    public init() {
        installHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    public func registerDefaults() {
        unregisterAll()

        let bindings: [(WindowCommand, Int, UInt32)] = [
            (.leftHalf, kVK_LeftArrow, Self.baseModifiers),
            (.rightHalf, kVK_RightArrow, Self.baseModifiers),
            (.maximize, kVK_UpArrow, Self.baseModifiers),
            (.restore, kVK_DownArrow, Self.baseModifiers),
            (.center, kVK_ANSI_C, Self.baseModifiers),
            (.topLeft, kVK_ANSI_U, Self.baseModifiers),
            (.topRight, kVK_ANSI_I, Self.baseModifiers),
            (.bottomLeft, kVK_ANSI_J, Self.baseModifiers),
            (.bottomRight, kVK_ANSI_K, Self.baseModifiers),
            (.previousDisplay, kVK_LeftArrow, Self.baseModifiers | UInt32(shiftKey)),
            (.nextDisplay, kVK_RightArrow, Self.baseModifiers | UInt32(shiftKey))
        ]

        for (index, binding) in bindings.enumerated() {
            let identifier = UInt32(index + 1)
            commandByID[identifier] = binding.0
            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
            let status = RegisterEventHotKey(
                UInt32(binding.1),
                binding.2,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                hotKeyRefs.append(reference)
            } else {
                DeckLog.app.error(
                    "Unable to register hotkey for \(binding.0.rawValue, privacy: .public), status \(status, privacy: .public)"
                )
            }
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            snapDeckHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            DeckLog.app.error("Unable to install hotkey event handler: \(status, privacy: .public)")
        }
    }

    private func unregisterAll() {
        for reference in hotKeyRefs {
            UnregisterEventHotKey(reference)
        }
        hotKeyRefs.removeAll()
        commandByID.removeAll()
    }

    fileprivate func handleHotKey(id: UInt32) {
        guard let command = commandByID[id] else { return }
        onAction?(command)
    }
}

private let snapDeckHotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKey(id: hotKeyID.id)
    return noErr
}
