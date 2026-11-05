import Foundation
import SwiftData

@MainActor
enum DoseActions {
    /// 自由录入时，最多往前/往后 3 小时去匹配计划时间
    static let matchWindow: TimeInterval = 3 * 3600

    static func toggleTaken(_ item: DoseItem, in context: ModelContext) {
        if item.state.isTaken {
            reset(item, in: context)
        } else {
            setTaken(item, at: defaultTakenTime(for: item.scheduledAt), in: context)
        }
    }

    /// 标记已服用，并指定实际服药时间
    static func setTaken(_ item: DoseItem, at time: Date, in context: ModelContext) {
        let time = trimSeconds(time)
        if let log = item.log {
            log.status = .taken
            log.takenAt = time
            if item.isExtra { log.scheduledAt = time }
        } else {
            context.insert(DoseLog(scheduledAt: item.scheduledAt, status: .taken, takenAt: time, medication: item.medication))
        }
        try? context.save()
    }

    static func skip(_ item: DoseItem, in context: ModelContext) {
        if let log = item.log {
            log.status = .skipped
            log.takenAt = nil
        } else {
            context.insert(DoseLog(scheduledAt: item.scheduledAt, status: .skipped, takenAt: nil, medication: item.medication))
        }
        try? context.save()
    }

    static func reset(_ item: DoseItem, in context: ModelContext) {
        if let log = item.log { context.delete(log) }
        try? context.save()
    }

    /// 自由录入：某个时间吃了哪几种药。
    /// 每种药会归到当天最近的、还没吃的计划时间（前后 3 小时内），否则记为计划外。
    static func record(_ medications: [Medication], at time: Date, in context: ModelContext) {
        let time = trimSeconds(time)
        let allMeds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        let items = DoseEngine.doses(on: time, medications: allMeds, logs: logs, now: time)

        for med in medications {
            let open = items.filter { $0.medication.id == med.id && !$0.isExtra && !$0.state.isTaken }
            let nearest = open.min {
                abs($0.scheduledAt.timeIntervalSince(time)) < abs($1.scheduledAt.timeIntervalSince(time))
            }
            if let slot = nearest, abs(slot.scheduledAt.timeIntervalSince(time)) <= matchWindow {
                if let log = slot.log {
                    log.status = .taken
                    log.takenAt = time
                } else {
                    context.insert(DoseLog(scheduledAt: slot.scheduledAt, status: .taken, takenAt: time, medication: med))
                }
            } else {
                context.insert(DoseLog(scheduledAt: time, status: .taken, takenAt: time, medication: med))
            }
        }
        try? context.save()
    }

    /// 从通知上的"已服用"按钮调用
    static func markTaken(medID: String, minute: Int, day: Date, in context: ModelContext) {
        guard let uuid = UUID(uuidString: medID) else { return }
        let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        guard let med = meds.first(where: { $0.id == uuid }) else { return }
        let at = ScheduleMath.date(minute: minute, on: day)
        if let existing = (med.logs ?? []).first(where: { abs($0.scheduledAt.timeIntervalSince(at)) < 60 }) {
            existing.status = .taken
            existing.takenAt = trimSeconds(.now)
        } else {
            context.insert(DoseLog(scheduledAt: at, status: .taken, takenAt: trimSeconds(.now), medication: med))
        }
        try? context.save()
    }

    /// 当天的就记现在，补记以前的就记计划时间
    static func defaultTakenTime(for scheduled: Date) -> Date {
        Calendar.current.isDateInToday(scheduled) ? .now : scheduled
    }

    static func trimSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
    }
}
