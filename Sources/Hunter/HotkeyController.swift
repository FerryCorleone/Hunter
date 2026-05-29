import ApplicationServices
import Foundation

@MainActor
final class HotkeyController {
    private let state: AppState
    private let voiceCommands: VoiceCommandController
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHoldingShortcut = false

    init(state: AppState, voiceCommands: VoiceCommandController) {
        self.state = state
        self.voiceCommands = voiceCommands
    }

    func start() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            state.permissionStatus = state.copy(
                "需要辅助功能权限才能使用 \(state.replyShortcut.displayText)",
                "Accessibility permission needed for \(state.replyShortcut.displayText) hotkey"
            )
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<HotkeyController>.fromOpaque(refcon).takeUnretainedValue()
                Task { @MainActor in
                    controller.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            state.permissionStatus = state.copy(
                "需要辅助功能权限才能使用 \(state.replyShortcut.displayText)",
                "Accessibility permission needed for \(state.replyShortcut.displayText) hotkey"
            )
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        state.permissionStatus = state.copy(
            "\(state.replyShortcut.displayText) 快捷键已启用",
            "\(state.replyShortcut.displayText) hotkey active"
        )
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isReplyShortcut = shortcutMatches(keyCode: keyCode, flags: flags)

        switch type {
        case .keyDown where isReplyShortcut && !isHoldingShortcut:
            isHoldingShortcut = true
            voiceCommands.beginRecording()
        case .keyUp where keyCode == state.replyShortcut.keyCode && isHoldingShortcut:
            isHoldingShortcut = false
            voiceCommands.finishRecording()
        default:
            break
        }
    }

    private func shortcutMatches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        let shortcut = state.replyShortcut
        guard keyCode == shortcut.keyCode else { return false }
        return shortcut.modifiers.allSatisfy { flags.contains($0.cgFlag) }
    }
}

private extension ReplyShortcutModifier {
    var cgFlag: CGEventFlags {
        switch self {
        case .command: .maskCommand
        case .control: .maskControl
        case .option: .maskAlternate
        case .shift: .maskShift
        }
    }
}
