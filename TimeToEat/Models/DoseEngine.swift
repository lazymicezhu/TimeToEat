import Foundation

enum DoseState: Equatable {
    case taken(Date)
    case skipped
    case missed
    case due
    case upcoming

    var isTaken: Bool {
        if case .taken = self { return true }
        return false
    }
    var isPending: Bool { self == .due || self == .upcoming }
}

struct DoseItem: Identifiable {
    let medication: Medication
    let minute: Int
    let scheduledAt: Date
    let log: DoseLog?
    let state: DoseState
    /// 不在服药计划里的额外一次（自由录入）
    var isExtra: Bool = false

    var id: String { DoseEngine.key(medication.id, scheduledAt) }
}

enum DoseEngine {
    /// 前后 30 分钟内算"该吃了"
    static let dueWindow: TimeInterval = 30 * 60

    static func key(_ medID: UUID, _ date: Date) -> String {
        "\(medID.uuidString)-\(Int(date.timeIntervalSince1970 / 60))"
    }

    static func doses(on day: Date, medications: [Medication], logs: [DoseLog], now: Date = .now) -> [DoseItem] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var logMap: [String: DoseLog] = [:]
        for log in logs where log.scheduledAt >= dayStart && log.scheduledAt < dayEnd {
            if let med = log.medication { logMap[key(med.id, log.scheduledAt)] = log }
        }

        var items: [DoseItem] = []
        var used = Set<String>()
        for med in medications where med.isActive && cal.startOfDay(for: med.createdAt) <= dayStart {
            for minute in med.dailyMinutes {
                let at = ScheduleMath.date(minute: minute, on: dayStart)
                let k = key(med.id, at)
                let log = logMap[k]
                if log != nil { used.insert(k) }
                let state: DoseState
                if let log {
                    state = log.status == .taken ? .taken(log.takenAt ?? at) : .skipped
                } else if at < now.addingTimeInterval(-dueWindow) {
                    state = .missed
                } else if at <= now.addingTimeInterval(dueWindow) {
                    state = .due
                } else {
                    state = .upcoming
                }
                items.append(DoseItem(medication: med, minute: minute, scheduledAt: at, log: log, state: state))
            }
        }
        // 没对应到计划时间的记录，作为"计划外"显示
        for (k, log) in logMap where !used.contains(k) {
            guard let med = log.medication else { continue }
            let state: DoseState = log.status == .taken ? .taken(log.takenAt ?? log.scheduledAt) : .skipped
            items.append(DoseItem(medication: med, minute: ScheduleMath.minute(of: log.scheduledAt),
                                  scheduledAt: log.scheduledAt, log: log, state: state, isExtra: true))
        }
        return items.sorted {
            $0.scheduledAt == $1.scheduledAt ? $0.medication.name < $1.medication.name : $0.scheduledAt < $1.scheduledAt
        }
    }
}

enum DayPeriod: Int, CaseIterable, Identifiable {
    case dawn, morning, noon, afternoon, evening

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .dawn: return "凌晨"
        case .morning: return "早上"
        case .noon: return "中午"
        case .afternoon: return "下午"
        case .evening: return "晚上"
        }
    }
    var icon: String {
        switch self {
        case .dawn: return "moon.stars.fill"
        case .morning: return "sunrise.fill"
        case .noon: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "moon.fill"
        }
    }

    static func of(minute: Int) -> DayPeriod {
        switch minute / 60 {
        case 0..<5: return .dawn
        case 5..<11: return .morning
        case 11..<14: return .noon
        case 14..<18: return .afternoon
        default: return .evening
        }
    }

    struct Group: Identifiable {
        let period: DayPeriod
        let items: [DoseItem]
        var id: Int { period.rawValue }
    }

    /// descending = true 时晚的在上（晚上 → 早上），组内也按时间倒序
    static func group(_ items: [DoseItem], descending: Bool = false) -> [Group] {
        let dict = Dictionary(grouping: items) { DayPeriod.of(minute: $0.minute) }
        let periods = descending ? Array(DayPeriod.allCases.reversed()) : DayPeriod.allCases
        return periods.compactMap { p in
            guard let list = dict[p], !list.isEmpty else { return nil }
            let sorted = descending
                ? list.sorted { $0.scheduledAt == $1.scheduledAt ? $0.medication.createdAt < $1.medication.createdAt : $0.scheduledAt > $1.scheduledAt }
                : list
            return Group(period: p, items: sorted)
        }
    }
}
