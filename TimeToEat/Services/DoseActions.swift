import Foundation
import SwiftData

@MainActor
enum DoseActions {
    /// 记录：某个时间吃了哪几种药
    static func record(_ medications: [Medication], at time: Date, in context: ModelContext) {
        let t = ScheduleMath.trimToMinute(time)
        for med in medications {
            context.insert(DoseLog(scheduledAt: t, status: .taken, takenAt: t, medication: med))
        }
        commit(context)
    }

    /// 修改一次记录：时间和吃了哪些药
    static func update(_ event: DoseEvent, time: Date, medications: [Medication], in context: ModelContext) {
        let t = ScheduleMath.trimToMinute(time)
        let keep = Set(medications.map(\.id))
        var present = Set<UUID>()
        for log in event.logs {
            guard let med = log.medication, keep.contains(med.id), !present.contains(med.id) else {
                context.delete(log)
                continue
            }
            log.scheduledAt = t
            log.takenAt = t
            log.status = .taken
            present.insert(med.id)
        }
        for med in medications where !present.contains(med.id) {
            context.insert(DoseLog(scheduledAt: t, status: .taken, takenAt: t, medication: med))
        }
        commit(context)
    }

    static func delete(_ event: DoseEvent, in context: ModelContext) {
        for log in event.logs { context.delete(log) }
        commit(context)
    }

    /// 通知上点"已服用"
    static func markTaken(medIDs: [String], in context: ModelContext) {
        let ids = Set(medIDs.compactMap(UUID.init(uuidString:)))
        let meds = ((try? context.fetch(FetchDescriptor<Medication>())) ?? []).filter { ids.contains($0.id) }
        guard !meds.isEmpty else { return }
        record(meds, at: .now, in: context)
    }

    private static func commit(_ context: ModelContext) {
        try? context.save()
        NotificationManager.shared.rescheduleAll(context)
    }
}
