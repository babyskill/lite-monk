import Foundation
import UserNotifications

/// Posts native notifications when an agent needs attention or finishes.
///
/// `UNUserNotificationCenter` requires a bundled, identified app; when run as a
/// bare binary (`swift run`) there is no bundle id, so we no-op to avoid a
/// crash. Notifications work once launched as `AgentPet.app`.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(title: String, body: String) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
