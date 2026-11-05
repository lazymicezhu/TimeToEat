import SwiftUI

struct DoseRow: View {
    let item: DoseItem
    let now: Date
    var onToggle: (() -> Void)?
    var onOpen: (() -> Void)?

    private var med: Medication { item.medication }
    private var isToday: Bool { Calendar.current.isDate(item.scheduledAt, inSameDayAs: now) }

    var body: some View {
        HStack(spacing: 14) {
            MedIcon(iconName: med.iconName, color: med.tint)
                .opacity(item.state.isTaken ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(med.name)
                        .font(.headline)
                        .strikethrough(item.state.isTaken, color: .secondary)
                        .foregroundStyle(item.state.isTaken ? .secondary : .primary)
                    if item.isExtra {
                        Text("计划外")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(med.tint)
                            .background(med.tint.opacity(0.12), in: Capsule())
                    }
                }
                if !med.detailLine.isEmpty {
                    Text(med.detailLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(ScheduleMath.format(item.minute))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.state.isTaken ? .secondary : .primary)
                statusLabel
            }

            if let onToggle {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .strokeBorder(item.state.isTaken ? Color.clear : med.tint.opacity(0.5), lineWidth: 2)
                            .background(Circle().fill(item.state.isTaken ? med.tint : .clear))
                        if item.state.isTaken {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.state.isTaken ? "撤销已服用" : "标记已服用")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { onOpen?() }
        .overlay {
            if item.state == .due {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(med.tint, lineWidth: 2)
            }
        }
        .opacity(item.state == .skipped ? 0.55 : 1)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch item.state {
        case .taken(let date):
            Label("已服 \(ScheduleMath.format(ScheduleMath.minute(of: date)))", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        case .skipped:
            Text("已跳过").font(.caption).foregroundStyle(.secondary)
        case .missed:
            if isToday {
                Text("已过 \(ScheduleMath.duration(Int(now.timeIntervalSince(item.scheduledAt) / 60)))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            } else {
                Text("漏服").font(.caption.weight(.medium)).foregroundStyle(.red)
            }
        case .due:
            Text("现在该吃了")
                .font(.caption.weight(.bold))
                .foregroundStyle(med.tint)
        case .upcoming:
            let mins = Int(item.scheduledAt.timeIntervalSince(now) / 60)
            Text(mins < 180 ? "还有 \(ScheduleMath.duration(mins))" : "待服用")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
