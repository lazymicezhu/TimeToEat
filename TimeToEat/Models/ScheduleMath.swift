import Foundation

enum ScheduleMath {
    static func minutes(mode: ScheduleMode, times: [Int], intervalHours: Int, start: Int, end: Int) -> [Int] {
        switch mode {
        case .timesPerDay:
            return Array(Set(times)).sorted()
        case .interval:
            let step = max(1, intervalHours) * 60
            // 允许跨越午夜，例如 20:00 → 次日 08:00
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

    static func presetTimes(count: Int) -> [Int] {
        switch count {
        case 1: return [8 * 60]
        case 2: return [8 * 60, 20 * 60]
        case 3: return [8 * 60, 13 * 60, 19 * 60]
        case 4: return [8 * 60, 12 * 60, 17 * 60, 21 * 60]
        default:
            // 从 7:00 到 22:00 均匀分布
            let span = 15 * 60
            return (0..<count).map { 7 * 60 + span * $0 / max(1, count - 1) / 5 * 5 }
        }
    }

    static func summary(mode: ScheduleMode, count: Int, intervalHours: Int) -> String {
        switch mode {
        case .timesPerDay: return "每天 \(count) 次"
        case .interval: return "每 \(intervalHours) 小时一次"
        }
    }

    static func format(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    static func date(minute: Int, on day: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) ?? day
    }

    static func minute(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func duration(_ minutes: Int) -> String {
        let m = abs(minutes)
        if m < 60 { return "\(max(1, m)) 分钟" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) 小时" : "\(h) 小时 \(r) 分"
    }

    /// 距离某个时间过去多久，例如 "26 分钟"、"2 小时 15 分"、"1 天 3 小时"
    static func elapsed(since date: Date, now: Date) -> String {
        let mins = Int(now.timeIntervalSince(date) / 60)
        if mins < 1 { return "不到 1 分钟" }
        if mins < 24 * 60 { return duration(mins) }
        let days = mins / 1440, hours = (mins % 1440) / 60
        return hours == 0 ? "\(days) 天" : "\(days) 天 \(hours) 小时"
    }

    /// "今天 23:08" / "昨天 17:28" / "11月3日 08:00"
    static func clock(_ date: Date) -> String {
        let cal = Calendar.current
        let time = format(minute(of: date))
        if cal.isDateInToday(date) { return "今天 \(time)" }
        if cal.isDateInYesterday(date) { return "昨天 \(time)" }
        let c = cal.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)月\(c.day ?? 0)日 \(time)"
    }
}
