import AppKit
import Foundation
// UNUserNotificationCenter predates strict concurrency; its completion
// handlers are thread-safe by contract but not annotated Sendable.
@preconcurrency import UserNotifications

/// What the panes need to know, plainly: can local notifications be
/// delivered, or has the system said no (spec: "Denied permission degrades
/// quietly").
enum NotificationAvailability: Equatable {
    case available, denied
}

/// One pending local notification, anchored on a canonical engine instant.
struct LocalNotificationRequest: Equatable {
    let id: String
    let body: String
    let at: Date
    let bringToFront: Bool
}

/// The seam between notification policy (AppModel, tested) and
/// UserNotifications (inert in tests).
protocol NotificationScheduling {
    func schedule(_ request: LocalNotificationRequest)
    func cancelPending()
    func checkAvailability(_ report: @escaping @MainActor (NotificationAvailability) -> Void)
}

/// Production scheduler. The calendar trigger fires even if the app has
/// quit — which is the point. Authorization is requested at most once (the
/// system itself never re-shows the dialog); denial is reported, never
/// worked around, never nagged.
final class LocalNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var pendingIDs: [String] = []

    override init() {
        super.init()
        // Sole delegate duty: honour the user's bring-to-front choice when
        // they act on a notification (validator finding 10).
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let bringToFront =
            response.notification.request.content.userInfo["bringToFront"] as? Bool ?? false
        if bringToFront {
            Task { @MainActor in NSApp.activate(ignoringOtherApps: true) }
        }
        completionHandler()
    }

    func checkAvailability(_ report: @escaping @MainActor (NotificationAvailability) -> Void) {
        center.getNotificationSettings { [center] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    Task { @MainActor in report(granted ? .available : .denied) }
                }
            case .denied:
                Task { @MainActor in report(.denied) }
            default:
                Task { @MainActor in report(.available) }
            }
        }
    }

    func schedule(_ request: LocalNotificationRequest) {
        let content = UNMutableNotificationContent()
        content.title = "Praxmodoro"
        content.body = request.body
        content.userInfo = ["bringToFront": request.bringToFront]
        // A calendar trigger takes the canonical instant directly — no
        // wall-clock read, no interval arithmetic in this layer.
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: request.at)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
        pendingIDs.append(request.id)
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        pendingIDs.removeAll()
    }
}
