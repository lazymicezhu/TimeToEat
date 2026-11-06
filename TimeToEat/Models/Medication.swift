import Foundation
import SwiftData

/// 旧版（1.0.x）的固定时间表方式，仅用于升级时推算间隔
enum ScheduleMode: String, Codable, CaseIterable, Identifiable {
    case timesPerDay
    case interval

    var id: String { rawValue }
}

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""
    var note: String = ""
    var iconName: String = "pills.fill"
    var colorName: String = "teal"
    // 旧版固定时间表字段
    var modeRaw: String = "timesPerDay"
    var times: [Int] = [480]
    var intervalHours: Int = 8
    var intervalStart: Int = 480
    var intervalEnd: Int = 1320
    /// 两次服药至少间隔多少分钟
    var minIntervalMinutes: Int = 360
    /// 每天最多吃几次
    var maxPerDay: Int = 3
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

    var legacyDailyMinutes: [Int] {
        ScheduleMath.minutes(mode: mode, times: times, intervalHours: intervalHours,
                             start: intervalStart, end: intervalEnd)
    }

    var detailLine: String {
        [dosage, note].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var ruleSummary: String {
        "至少隔 \(ScheduleMath.duration(minIntervalMinutes)) · 每天最多 \(maxPerDay) 次"
    }
}
