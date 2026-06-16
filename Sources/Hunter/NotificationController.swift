import Foundation
import UserNotifications

struct NotificationController {
    func notifyCatch(target: String, roast: String) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(AppBrand.displayName)抓到你在 \(target)"
        content.body = roast
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "hunter-catch-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
