import Foundation
import SwiftData
import UIKit
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private static let category = "DOSE"
    private static let takenAction = "TAKEN"
    private static let snoozeAction = "SNOOZE"

    func configure() {
        center.delegate = self
        let taken = UNNotificationAction(identifier: Self.takenAction, title: "已服用", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "10 分钟后再提醒", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [taken, snooze], intentIdentifiers: [], options: [])
        ])
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshStatus()
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
        }
        return status == .authorized || status == .provisional
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func rescheduleAll(_ context: ModelContext) {
        let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        reschedule(meds)
    }

    /// 每个服药时间点注册一个按天重复的本地通知
    func reschedule(_ meds: [Medication]) {
        var requests: [UNNotificationRequest] = []
        for med in meds where med.isActive && med.remindersOn {
            for minute in med.dailyMinutes {
                let content = UNMutableNotificationContent()
                content.title = "该吃药了 · \(med.name)"
                content.body = med.detailLine.isEmpty ? "现在是 \(ScheduleMath.format(minute))，记得按时服药" : "\(med.detailLine)，记得按时服药"
                content.sound = .default
                content.categoryIdentifier = Self.category
                content.userInfo = ["medID": med.id.uuidString, "minute": minute]
                var comps = DateComponents()
                comps.hour = minute / 60
                comps.minute = minute % 60
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                requests.append(UNNotificationRequest(identifier: "dose-\(med.id.uuidString)-\(minute)", content: content, trigger: trigger))
            }
        }
        Task {
            let pending = await center.pendingNotificationRequests()
            let stale = pending.map(\.identifier).filter { $0.hasPrefix("dose-") }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            // iOS 最多保留 64 个待发送通知
            for r in requests.prefix(60) { try? await center.add(r) }
        }
    }

    private func snooze(medID: String, minute: Int, day: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["medID": medID, "minute": minute, "day": day.timeIntervalSince1970]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        center.add(UNNotificationRequest(identifier: "snooze-\(medID)-\(minute)", content: content, trigger: trigger))
    }

    private func handle(action: String, medID: String, minute: Int, day: Date, title: String, body: String) {
        switch action {
        case Self.takenAction:
            DoseActions.markTaken(medID: medID, minute: minute, day: day, in: Persistence.container.mainContext)
        case Self.snoozeAction:
            snooze(medID: medID, minute: minute, day: day, title: title, body: body)
        default:
            break
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let info = content.userInfo
        guard let medID = info["medID"] as? String, let minute = info["minute"] as? Int else { return }
        let day: Date
        if let ts = info["day"] as? Double {
            day = Date(timeIntervalSince1970: ts)
        } else {
            day = response.notification.date
        }
        let action = response.actionIdentifier
        let title = content.title
        let body = content.body
        await handle(action: action, medID: medID, minute: minute, day: day, title: title, body: body)
    }
}
