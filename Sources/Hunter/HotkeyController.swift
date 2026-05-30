import Carbon
import AppKit
import Combine
import Foundation

@MainActor
final class HotkeyController {
    private let state: AppState
    private let voiceCommands: VoiceCommandController
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localFlagsMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []
    private var isHoldingShortcut = false
    private let signature = OSType(UInt32(ascii: "HUNT"))

    init(state: AppState, voiceCommands: VoiceCommandController) {
        self.state = state
        self.voiceCommands = voiceCommands
    }

    func start() {
        installEventHandlerIfNeeded()
        registerCurrentShortcut()
        state.$replyShortcut
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerCurrentShortcut()
            }
            .store(in: &cancellables)
    }

    func stop() {
        unregisterCurrentShortcut()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
        cancellables.removeAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, refcon in
                guard let refcon else { return noErr }
                let controller = Unmanaged<HotkeyController>.fromOpaque(refcon).takeUnretainedValue()
                let kind = event.map { GetEventKind($0) } ?? 0
                Task { @MainActor in
                    controller.handle(eventKind: kind)
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            refcon,
            &eventHandlerRef
        )
        if status != noErr {
            ASRDiagnostics.record("HOTKEY_HANDLER_FAILED status=\(status)")
            state.permissionStatus = state.copy("快捷键监听启动失败：\(status)", "Hotkey listener failed: \(status)")
        } else {
            ASRDiagnostics.record("HOTKEY_HANDLER_READY")
        }
    }

    private func registerCurrentShortcut() {
        unregisterCurrentShortcut()
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let shortcut = state.replyShortcut
        if shortcut.isModifierOnly {
            registerModifierOnlyShortcut(shortcut)
            return
        }

        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            ASRDiagnostics.record("HOTKEY_REGISTERED shortcut=\(shortcut.displayText)")
            state.permissionStatus = state.copy(
                "\(shortcut.displayText) 快捷键已启用",
                "\(shortcut.displayText) hotkey active"
            )
        } else {
            ASRDiagnostics.record("HOTKEY_REGISTER_FAILED shortcut=\(shortcut.displayText) status=\(status)")
            state.permissionStatus = state.copy(
                "\(shortcut.displayText) 快捷键注册失败：\(status)",
                "\(shortcut.displayText) hotkey failed: \(status)"
            )
        }
    }

    private func unregisterCurrentShortcut() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
        }
        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
        }
        localFlagsMonitor = nil
        globalFlagsMonitor = nil
        isHoldingShortcut = false
    }

    private func registerModifierOnlyShortcut(_ shortcut: ReplyShortcut) {
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleModifierOnlyEvent(event)
            }
            return event
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleModifierOnlyEvent(event)
            }
        }
        ASRDiagnostics.record("HOTKEY_REGISTERED_MODIFIER_ONLY shortcut=\(shortcut.displayText)")
        state.permissionStatus = state.copy(
            "\(shortcut.displayText) 单键快捷键已启用",
            "\(shortcut.displayText) single-key hotkey active"
        )
    }

    private func handle(eventKind: UInt32) {
        switch eventKind {
        case UInt32(kEventHotKeyPressed) where !isHoldingShortcut:
            ASRDiagnostics.record("HOTKEY_PRESSED")
            isHoldingShortcut = true
            voiceCommands.beginManualReply()
        case UInt32(kEventHotKeyReleased) where isHoldingShortcut:
            ASRDiagnostics.record("HOTKEY_RELEASED")
            isHoldingShortcut = false
            voiceCommands.finishManualReply()
        default:
            break
        }
    }

    private func handleModifierOnlyEvent(_ event: NSEvent) {
        let shortcut = state.replyShortcut
        guard shortcut.isModifierOnly,
              event.keyCode == shortcut.keyCode,
              let modifier = shortcut.modifierOnlyKind?.eventFlag
        else {
            return
        }

        let isPressed = event.modifierFlags.contains(modifier)
        if isPressed, !isHoldingShortcut {
            ASRDiagnostics.record("HOTKEY_MODIFIER_ONLY_PRESSED shortcut=\(shortcut.displayText)")
            isHoldingShortcut = true
            voiceCommands.beginManualReply()
        } else if !isPressed, isHoldingShortcut {
            ASRDiagnostics.record("HOTKEY_MODIFIER_ONLY_RELEASED shortcut=\(shortcut.displayText)")
            isHoldingShortcut = false
            voiceCommands.finishManualReply()
        }
    }
}

private extension ReplyShortcut {
    var carbonModifierFlags: UInt32 {
        modifiers.reduce(UInt32(0)) { partial, modifier in
            partial | modifier.carbonFlag
        }
    }
}

private extension ReplyShortcutModifier {
    var carbonFlag: UInt32 {
        switch self {
        case .command: UInt32(cmdKey)
        case .control: UInt32(controlKey)
        case .option: UInt32(optionKey)
        case .shift: UInt32(shiftKey)
        }
    }

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .command: .command
        case .control: .control
        case .option: .option
        case .shift: .shift
        }
    }
}

private extension UInt32 {
    init(ascii text: String) {
        self = text.utf8.reduce(UInt32(0)) { ($0 << 8) + UInt32($1) }
    }
}
