import SwiftUI

/// 一次服药记录：时间 + 这次吃的药
struct EventRow: View {
    let event: DoseEvent

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(ScheduleMath.format(event.minute))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(event.medications.enumerated()), id: \.offset) { _, med in
                    HStack(spacing: 10) {
                        MedIcon(iconName: med.iconName, color: med.tint, size: 28)
                        Text(med.name).font(.body.weight(.medium))
                        if !med.dosage.isEmpty {
                            Text(med.dosage).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
