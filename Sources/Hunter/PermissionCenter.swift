import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import UserNotifications

enum PermissionState: String, Codable, Equatable {
    case allowed
    case notDetermined
    case denied
    case unknown

    func label(language: AppLanguage, optional: Bool = false) -> String {
        let english = language == .english
        if optional, self != .allowed {
            return english ? "Optional" : "可选"
        }
        return switch self {
        case .allowed: english ? "Allowed" : "已允许"
        case .notDetermined: english ? "Not asked" : "未请求"
        case .denied: english ? "Needs action" : "需要处理"
        case .unknown: english ? "Unknown" : "未知"
        }
    }
}

struct PermissionSnapshot: Codable, Equatable {
    var accessibility: PermissionState = .unknown
    var microphone: PermissionState = .unknown
    var notifications: PermissionState = .unknown
    var browserAutomation: PermissionState = .unknown
}

@MainActor
struct PermissionCenter {
    func snapshot() async -> PermissionSnapshot {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        return PermissionSnapshot(
            accessibility: accessibilityState,
            microphone: microphoneState,
            notifications: notificationState(from: notificationSettings.authorizationStatus),
            browserAutomation: browserAutomationState()
        )
    }

    func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func requestNotifications() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    @discardableResult
    func requestBrowserAutomationPermission() -> Bool {
        let targetBundleID = preferredBrowserBundleID()
        return BrowserURLReader().requestAutomationPermission(for: targetBundleID)
    }

    func openAccessibilitySettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openMicrophoneSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openNotificationSettings() {
        openSettings("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    private var microphoneState: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .allowed
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .unknown
        }
    }

    private var accessibilityState: PermissionState {
        let trusted = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": false
        ] as CFDictionary)
        return trusted ? .allowed : .denied
    }

    private func notificationState(from status: UNAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized, .provisional, .ephemeral: .allowed
        case .notDetermined: .notDetermined
        case .denied: .denied
        @unknown default: .unknown
        }
    }

    private func browserAutomationState() -> PermissionState {
        guard let bundleID = preferredBrowserBundleID() else {
            return .unknown
        }
        return BrowserURLReader.canReadAutomation(bundleID: bundleID, askUserIfNeeded: false)
            ? .allowed
            : .denied
    }

    private func preferredBrowserBundleID() -> String? {
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if BrowserURLReader.isSupportedBrowser(bundleID: frontmostBundleID) {
            return frontmostBundleID
        }
        if let runningBrowser = NSWorkspace.shared.runningApplications
            .compactMap(\.bundleIdentifier)
            .first(where: { BrowserURLReader.isSupportedBrowser(bundleID: $0) }) {
            return runningBrowser
        }
        return "com.google.Chrome"
    }

    private func openSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
