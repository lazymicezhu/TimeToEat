import Foundation
import SwiftData

/// 首次启动时写入用户自己的三种药，以及 2026-11-05 的服药记录。
/// 只会写一次：之后即使把药全删了也不会再写回来。带 -demo 启动参数且数据库为空时可强制重新写入。
@MainActor
enum InitialData {
    private static let seededKey = "didSeedInitialData"

    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard LaunchOptions.demo || !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)
        let count = (try? context.fetchCount(FetchDescriptor<Medication>())) ?? 0
        guard count == 0 else { return }

        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2026, month: 11, day: 5)) ?? cal.startOfDay(for: .now)

        var order: TimeInterval = 0
        func make(_ name: String, _ icon: String, _ color: String, times: [Int]) -> Medication {
            order += 1
            let m = Medication(name: name)
            m.dosage = ""
            m.iconName = icon
            m.colorName = color
            m.mode = .timesPerDay
            m.times = times
            m.createdAt = day.addingTimeInterval(order)  // 错开几秒，保证列表顺序稳定
            context.insert(m)
            return m
        }

        let metronidazole = make("甲硝唑", "pills.fill", "blue", times: [11 * 60 + 30, 17 * 60 + 30, 23 * 60])
        let amoxicillin = make("阿莫西林", "capsule.fill", "orange", times: [11 * 60 + 30, 17 * 60 + 30, 23 * 60])
        let etoricoxib = make("依托考昔", "cross.vial.fill", "pink", times: [12 * 60 + 45])
        try? context.save()

        func at(_ h: Int, _ m: Int) -> Date { ScheduleMath.date(minute: h * 60 + m, on: day) }
        DoseActions.record([metronidazole, amoxicillin], at: at(11, 30), in: context)
        DoseActions.record([etoricoxib], at: at(12, 47), in: context)
        DoseActions.record([metronidazole, amoxicillin], at: at(17, 28), in: context)
        DoseActions.record([metronidazole, amoxicillin], at: at(23, 8), in: context)
    }
}
