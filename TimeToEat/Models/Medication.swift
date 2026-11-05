import Foundation
import SwiftData

enum ScheduleMode: String, Codable, CaseIterable, Identifiable {
    case timesPerDay
    case interval

    var id: String { rawValue }
    var title: String {
        switch self {
        case .timesPerDay: return "每天几次"
        case .interval: return "隔多久一次"
        }
    }
}

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""
    var note: String = ""
    var iconName: String = "pills.fill"
    var colorName: String = "teal"
    var modeRaw: String = "timesPerDay"
    /// 每天固定时间（距 0 点的分钟数）
    var times: [Int] = [480]
    var intervalHours: Int = 8
    var intervalStart: Int = 480
    var intervalEnd: Int = 1320
    var remindersOn: Bool = true
    var isActive: Bool = true
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var logs: [DoseLog]? = []

    init(name: String) {
        self.name = name
    }

    var mode: ScheduleMode {
        get { ScheduleMode(rawValue: modeRaw) ?? .timesPerDay }
        set { modeRaw = newValue.rawValue }
    }

    /// 每天需要服药的时间点（分钟）
    var dailyMinutes: [Int] {
        ScheduleMath.minutes(mode: mode, times: times, intervalHours: intervalHours,
                             start: intervalStart, end: intervalEnd)
    }

    var scheduleSummary: String {
        ScheduleMath.summary(mode: mode, count: dailyMinutes.count, intervalHours: intervalHours)
    }

    var detailLine: String {
        [dosage, note].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// 最近一次实际服药时间
    func lastTaken(before now: Date = .now) -> Date? {
        (logs ?? [])
            .filter { $0.status == .taken }
            .compactMap(\.takenAt)
            .filter { $0 <= now }
            .max()
    }
}
