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

    func label(language: AppLanguage) -> String {
        let english = language == .english
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
}

@MainActor
struct PermissionCenter {
    func snapshot() async -> PermissionSnapshot {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        return PermissionSnapshot(
            accessibility: AXIsProcessTrusted() ? .allowed : .denied,
            microphone: microphoneState,
            notifications: notificationState(from: notificationSettings.authorizationStatus)
        )
    }

    func requestNotifications() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
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

    private func notificationState(from status: UNAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized, .provisional, .ephemeral: .allowed
        case .notDetermined: .notDetermined
        case .denied: .denied
        @unknown default: .unknown
        }
    }

    private func openSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
