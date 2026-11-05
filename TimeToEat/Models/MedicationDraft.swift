import Foundation

/// 编辑页使用的临时副本，点"取消"时不会污染数据
struct MedicationDraft {
    var name = ""
    var dosage = "1 片"
    var note = ""
    var iconName = "pills.fill"
    var colorName = "teal"
    var mode: ScheduleMode = .timesPerDay
    var times: [Int] = [8 * 60]
    var intervalHours = 8
    var intervalStart = 8 * 60
    var intervalEnd = 22 * 60
    var remindersOn = true
    var isActive = true

    init() {}

    init(_ m: Medication) {
        name = m.name
        dosage = m.dosage
        note = m.note
        iconName = m.iconName
        colorName = m.colorName
        mode = m.mode
        times = m.times.isEmpty ? [8 * 60] : m.times.sorted()
        intervalHours = m.intervalHours
        intervalStart = m.intervalStart
        intervalEnd = m.intervalEnd
        remindersOn = m.remindersOn
        isActive = m.isActive
    }

    func apply(to m: Medication) {
        m.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        m.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        m.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        m.iconName = iconName
        m.colorName = colorName
        m.mode = mode
        m.times = times.sorted()
        m.intervalHours = intervalHours
        m.intervalStart = intervalStart
        m.intervalEnd = intervalEnd
        m.remindersOn = remindersOn
        m.isActive = isActive
    }

    var dailyMinutes: [Int] {
        ScheduleMath.minutes(mode: mode, times: times, intervalHours: intervalHours,
                             start: intervalStart, end: intervalEnd)
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !dailyMinutes.isEmpty
    }
}
