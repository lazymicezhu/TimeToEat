import Foundation

enum ScheduleMath {
    /// 旧版时间表展开成每天的分钟数（仅升级时使用）
    static func minutes(mode: ScheduleMode, times: [Int], intervalHours: Int, start: Int, end: Int) -> [Int] {
        switch mode {
        case .timesPerDay:
            return Array(Set(times)).sorted()
        case .interval:
            let step = max(1, intervalHours) * 60
            let endMinute = end >= start ? end : end + 1440
            var result: [Int] = []
            var m = start
            while m <= endMinute {
                result.append(m % 1440)
                m += step
            }
            return Array(Set(result)).sorted()
        }
    }

    static func format(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    static func date(minute: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) ?? day
    }

    static func minute(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func trimToMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
    }

    static func duration(_ minutes: Int) -> String {
        let m = abs(minutes)
        if m < 60 { return "\(max(1, m)) 分钟" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) 小时" : "\(h) 小时 \(r) 分"
    }

    /// 距离某个时间过去多久，例如 "26 分钟"、"2 小时 15 分"、"1 天 3 小时"
    static func elapsed(since date: Date, now: Date) -> String {
        span(Int(now.timeIntervalSince(date) / 60))
    }

    /// 还要等多久
    static func remaining(until date: Date, now: Date) -> String {
        span(Int(ceil(date.timeIntervalSince(now) / 60)))
    }

    private static func span(_ mins: Int) -> String {
        if mins < 1 { return "不到 1 分钟" }
        if mins < 24 * 60 { return duration(mins) }
        let days = mins / 1440, hours = (mins % 1440) / 60
        return hours == 0 ? "\(days) 天" : "\(days) 天 \(hours) 小时"
    }

    /// "今天" / "明天" / "昨天" / "11月3日"
    static func dayPrefix(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "今天" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: t) { return "明天" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: y) { return "昨天" }
        let c = cal.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)月\(c.day ?? 0)日"
    }

    /// "今天 23:08" / "昨天 17:28" / "明天 04:08"
    static func clock(_ date: Date, now: Date = .now) -> String {
        "\(dayPrefix(date, now: now)) \(format(minute(of: date)))"
    }
}
