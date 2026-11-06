import Foundation
import SwiftData
import UIKit
import UserNotifications

/// 到了"下次最早可以吃"的时间就提醒一次
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
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        reschedule(meds: meds, logs: logs)
    }

    func reschedule(meds: [Medication], logs: [DoseLog], now: Date = .now) {
        let nexts = DoseEngine.nextDoses(meds.filter(\.remindersOn), logs: logs, now: now)
            .filter { ($0.earliest ?? .distantPast) > now }
        var requests: [UNNotificationRequest] = []
        for group in DoseEngine.groups(nexts, now: now) {
            guard let date = group.earliest else { continue }
            let content = makeContent(names: group.names, medIDs: group.items.map(\.medication.id.uuidString))
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            requests.append(UNNotificationRequest(identifier: "next-\(Int(date.timeIntervalSince1970))",
                                                  content: content, trigger: trigger))
        }
        Task {
            let pending = await center.pendingNotificationRequests()
            // 也清掉 1.0.x 留下的每日固定提醒
            let stale = pending.map(\.identifier).filter { $0.hasPrefix("next-") || $0.hasPrefix("dose-") }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for r in requests { try? await center.add(r) }
        }
    }

    private func makeContent(names: String, medIDs: [String]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "可以吃药了"
        content.body = "\(names) 已经到间隔时间，现在可以吃了"
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["medIDs": medIDs, "names": names]
        return content
    }

    private func handle(action: String, medIDs: [String], names: String) {
        switch action {
        case Self.takenAction:
            DoseActions.markTaken(medIDs: medIDs, in: Persistence.container.mainContext)
        case Self.snoozeAction:
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
            center.add(UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)",
                                             content: makeContent(names: names, medIDs: medIDs), trigger: trigger))
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
        let info = response.notification.request.content.userInfo
        guard let medIDs = info["medIDs"] as? [String] else { return }
        let names = info["names"] as? String ?? ""
        let action = response.actionIdentifier
        await handle(action: action, medIDs: medIDs, names: names)
    }
}
