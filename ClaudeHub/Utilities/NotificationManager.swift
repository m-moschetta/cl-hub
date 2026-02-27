import Foundation
import UserNotifications
import ClaudeHubCore

/// Manages macOS notifications for session status changes.
final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    /// Request notification permissions.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
        }
    }

    /// Notify when a session transitions from thinking to idle.
    func notifyCompletion(sessionName: String) {
        guard UserDefaults.standard.bool(forKey: "notifyOnCompletion") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Claude finished"
        content.body = "\(sessionName) is ready for input"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "completion-\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notify on error.
    func notifyError(sessionName: String, preview: String) {
        guard UserDefaults.standard.bool(forKey: "notifyOnError") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Error in \(sessionName)"
        content.body = String(preview.prefix(100))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "error-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notify on disconnection.
    func notifyDisconnected(sessionName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Session disconnected"
        content.body = "\(sessionName) process terminated"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "disconnected-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
