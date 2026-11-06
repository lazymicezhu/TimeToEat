import Foundation

/// 某种药下次最早什么时候能吃
struct NextDose: Identifiable {
    let medication: Medication
    let last: Date?
    let takenToday: Int
    /// nil 表示还没吃过，随时可以吃
    let earliest: Date?

    var id: UUID { medication.id }

    func isReady(at now: Date) -> Bool {
        guard let earliest else { return true }
        return earliest <= now
    }
}

/// 顶部卡片里，最早时间相同的药合并显示
struct NextGroup: Identifiable {
    let ready: Bool
    let earliest: Date?
    let items: [NextDose]

    var id: String { ready ? "ready" : "\(Int(earliest?.timeIntervalSince1970 ?? 0))" }
    var names: String { items.map(\.medication.name).joined(separator: "、") }
    var lastTaken: Date? { items.compactMap(\.last).max() }
}

/// 同一分钟记录的一次服药（可能同时吃了几种药）
struct DoseEvent: Identifiable {
    let time: Date
    let logs: [DoseLog]

    var id: Date { time }
    var minute: Int { ScheduleMath.minute(of: time) }
    var medications: [Medication] {
        logs.compactMap(\.medication).sorted { $0.createdAt < $1.createdAt }
    }
}

enum DoseEngine {
    static func takenTimes(of med: Medication, logs: [DoseLog]) -> [Date] {
        logs.filter { $0.status == .taken && $0.medication?.id == med.id }.map(\.time)
    }

    static func next(for med: Medication, logs: [DoseLog], now: Date = .now) -> NextDose {
        let cal = Calendar.current
        let times = takenTimes(of: med, logs: logs).filter { $0 <= now }
        let last = times.max()
        let today = times.filter { cal.isDate($0, inSameDayAs: now) }.count
        var earliest: Date?
        if let last {
            var e = last.addingTimeInterval(TimeInterval(med.minIntervalMinutes * 60))
            // 当天已经吃满次数，要等到第二天
            if med.maxPerDay > 0, today >= med.maxPerDay,
               let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) {
                e = max(e, tomorrow)
            }
            earliest = e
        }
        return NextDose(medication: med, last: last, takenToday: today, earliest: earliest)
    }

    static func nextDoses(_ meds: [Medication], logs: [DoseLog], now: Date = .now) -> [NextDose] {
        meds.filter(\.isActive)
            .map { next(for: $0, logs: logs, now: now) }
            .sorted {
                let a = $0.earliest ?? .distantPast, b = $1.earliest ?? .distantPast
                return a == b ? $0.medication.createdAt < $1.medication.createdAt : a < b
            }
    }

    static func groups(_ nexts: [NextDose], now: Date) -> [NextGroup] {
        let ready = nexts.filter { $0.isReady(at: now) }
        let waiting = nexts.filter { !$0.isReady(at: now) }
        var result: [NextGroup] = ready.isEmpty ? [] : [NextGroup(ready: true, earliest: nil, items: ready)]
        let byMinute = Dictionary(grouping: waiting) { ScheduleMath.trimToMinute($0.earliest ?? now) }
        for key in byMinute.keys.sorted() {
            let items = (byMinute[key] ?? []).sorted { $0.medication.createdAt < $1.medication.createdAt }
            result.append(NextGroup(ready: false, earliest: key, items: items))
        }
        return result
    }

    /// 某一天的服药记录，按时间倒序
    static func events(on day: Date, logs: [DoseLog]) -> [DoseEvent] {
        let cal = Calendar.current
        let dayLogs = logs.filter { $0.status == .taken && $0.medication != nil && cal.isDate($0.time, inSameDayAs: day) }
        let grouped = Dictionary(grouping: dayLogs) { ScheduleMath.trimToMinute($0.time) }
        return grouped.map { DoseEvent(time: $0.key, logs: $0.value) }.sorted { $0.time > $1.time }
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
        let events: [DoseEvent]
        var id: Int { period.rawValue }
    }

    /// 晚的在上：晚上 → 下午 → 中午 → 早上 → 凌晨
    static func group(_ events: [DoseEvent]) -> [Group] {
        let dict = Dictionary(grouping: events) { DayPeriod.of(minute: $0.minute) }
        return DayPeriod.allCases.reversed().compactMap { p in
            guard let list = dict[p], !list.isEmpty else { return nil }
            return Group(period: p, events: list.sorted { $0.time > $1.time })
        }
    }
}
