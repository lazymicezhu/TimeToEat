import Foundation
import SwiftData

@MainActor
enum InitialData {
    private static let seededKey = "didSeedInitialData"
    private static let migratedKey = "didMigrateToIntervals"

    static func prepare(_ context: ModelContext) {
        migrateIfNeeded(context)
        seedIfNeeded(context)
    }

    /// 1.0.x 用的是固定时间表；升级后按原时间表推算"至少间隔"和"每天最多几次"
    private static func migrateIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        for m in meds {
            let mins = m.legacyDailyMinutes
            m.maxPerDay = max(1, mins.count)
            if m.mode == .interval {
                m.minIntervalMinutes = max(1, m.intervalHours) * 60
            } else if mins.count <= 1 {
                m.minIntervalMinutes = 24 * 60
            } else {
                let gaps = zip(mins, Array(mins.dropFirst()) + [mins[0] + 1440]).map { $1 - $0 }
                m.minIntervalMinutes = max(60, (gaps.min() ?? 360) / 60 * 60)
            }
        }
        try? context.save()
    }

    /// 首次启动写入用户自己的三种药和 2026-11-05 的服药记录，只写一次。
    /// 带 -demo 启动参数且没有药品时可重新写入。
    private static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard LaunchOptions.demo || !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)
        let count = (try? context.fetchCount(FetchDescriptor<Medication>())) ?? 0
        guard count == 0 else { return }

        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 5)) ?? cal.startOfDay(for: .now)

        var order: TimeInterval = 0
        func make(_ name: String, _ icon: String, _ color: String, intervalHours: Int, perDay: Int) -> Medication {
            order += 1
            let m = Medication(name: name)
            m.dosage = ""
            m.iconName = icon
            m.colorName = color
            m.minIntervalMinutes = intervalHours * 60
            m.maxPerDay = perDay
            m.createdAt = day.addingTimeInterval(order)  // 错开几秒，保证列表顺序稳定
            context.insert(m)
            return m
        }

        let metronidazole = make("甲硝唑", "pills.fill", "blue", intervalHours: 5, perDay: 3)
        let amoxicillin = make("阿莫西林", "capsule.fill", "orange", intervalHours: 5, perDay: 3)
        let etoricoxib = make("依托考昔", "cross.vial.fill", "pink", intervalHours: 24, perDay: 1)
        try? context.save()

        func at(_ h: Int, _ m: Int) -> Date { ScheduleMath.date(minute: h * 60 + m, on: day) }
        DoseActions.record([metronidazole, amoxicillin], at: at(11, 30), in: context)
        DoseActions.record([etoricoxib], at: at(12, 47), in: context)
        DoseActions.record([metronidazole, amoxicillin], at: at(17, 28), in: context)
        DoseActions.record([metronidazole, amoxicillin], at: at(23, 8), in: context)

        // 仅用于截图对比：模拟两种抗生素 2 小时前刚吃过
        if LaunchOptions.args.contains("-scenario") {
            DoseActions.record([metronidazole, amoxicillin], at: Date.now.addingTimeInterval(-122 * 60), in: context)
        }
    }
}
