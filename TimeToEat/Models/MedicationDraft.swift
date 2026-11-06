import Foundation

/// 编辑页使用的临时副本，点"取消"时不会污染数据
struct MedicationDraft {
    var name = ""
    var dosage = "1 片"
    var note = ""
    var iconName = "pills.fill"
    var colorName = "teal"
    var minIntervalMinutes = 6 * 60
    var maxPerDay = 3
    var remindersOn = true
    var isActive = true

    init() {}

    init(_ m: Medication) {
        name = m.name
        dosage = m.dosage
        note = m.note
        iconName = m.iconName
        colorName = m.colorName
        minIntervalMinutes = m.minIntervalMinutes
        maxPerDay = m.maxPerDay
        remindersOn = m.remindersOn
        isActive = m.isActive
    }

    func apply(to m: Medication) {
        m.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        m.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        m.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        m.iconName = iconName
        m.colorName = colorName
        m.minIntervalMinutes = minIntervalMinutes
        m.maxPerDay = maxPerDay
        m.remindersOn = remindersOn
        m.isActive = isActive
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
