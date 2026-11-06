import Foundation
import SwiftData

enum DoseLogStatus: String, Codable {
    case taken
    case skipped
}

/// 一次实际服药
@Model
final class DoseLog {
    var scheduledAt: Date = Date()
    var takenAt: Date?
    var statusRaw: String = "taken"
    var medication: Medication?

    init(scheduledAt: Date, status: DoseLogStatus, takenAt: Date?, medication: Medication) {
        self.scheduledAt = scheduledAt
        self.statusRaw = status.rawValue
        self.takenAt = takenAt
        self.medication = medication
    }

    var status: DoseLogStatus {
        get { DoseLogStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    /// 实际服药时间
    var time: Date { takenAt ?? scheduledAt }
}
