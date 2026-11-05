import SwiftData
import SwiftUI

/// 自由录入：选时间 + 勾选这次吃了哪些药
struct RecordDoseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.createdAt) private var meds: [Medication]

    @State private var time: Date
    @State private var selected: Set<UUID>

    init(initialTime: Date = .now, preselected: Set<UUID> = []) {
        _time = State(initialValue: initialTime)
        _selected = State(initialValue: preselected)
    }

    private var activeMeds: [Medication] { meds.filter(\.isActive) }

    var body: some View {
        NavigationStack {
            Form {
                Section("什么时候吃的") {
                    DatePicker("服药时间", selection: $time, in: ...Date.now.addingTimeInterval(300),
                               displayedComponents: [.date, .hourAndMinute])
                    QuickTimeChips(time: $time, options: [
                        ("现在", 0), ("15 分钟前", 15), ("30 分钟前", 30), ("1 小时前", 60),
                    ])
                }

                Section {
                    if activeMeds.isEmpty {
                        Text("还没有药品，先去「我的药」添加").foregroundStyle(.secondary)
                    }
                    ForEach(activeMeds) { med in
                        let isOn = selected.contains(med.id)
                        Button {
                            if isOn { selected.remove(med.id) } else { selected.insert(med.id) }
                        } label: {
                            HStack(spacing: 12) {
                                MedIcon(iconName: med.iconName, color: med.tint, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(med.name).font(.body.weight(.medium))
                                    Text(med.detailLine.isEmpty ? med.scheduleSummary : med.detailLine)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isOn ? med.tint : Color(.tertiaryLabel))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("吃了哪些药（可多选）")
                } footer: {
                    Text("会自动对应到当天最近的计划时间（前后 3 小时内），对不上的记为「计划外」。")
                }
            }
            .navigationTitle("记录服药")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.count > 1 ? "记录 \(selected.count) 种" : "记录") { save() }
                        .fontWeight(.semibold)
                        .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func save() {
        let chosen = activeMeds.filter { selected.contains($0.id) }
        withAnimation(.snappy) { DoseActions.record(chosen, at: time, in: context) }
        dismiss()
    }
}

/// 单次服药：修改实际服药时间 / 跳过 / 撤销
struct DoseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let item: DoseItem
    @State private var time: Date

    init(item: DoseItem) {
        self.item = item
        let initial: Date
        if case .taken(let d) = item.state {
            initial = d
        } else {
            initial = min(DoseActions.defaultTakenTime(for: item.scheduledAt), .now)
        }
        _time = State(initialValue: initial)
    }

    private var med: Medication { item.medication }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        MedIcon(iconName: med.iconName, color: med.tint, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(med.name).font(.title3.bold())
                            if !med.detailLine.isEmpty {
                                Text(med.detailLine).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text(item.isExtra ? "计划外服药" : "计划时间 \(ScheduleMath.format(item.minute))")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(med.tint)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("实际服药时间") {
                    DatePicker("时间", selection: $time, in: ...Date.now.addingTimeInterval(300),
                               displayedComponents: [.date, .hourAndMinute])
                    if !item.isExtra {
                        Button("按计划时间 \(ScheduleMath.format(item.minute))") { time = item.scheduledAt }
                            .disabled(item.scheduledAt > .now)
                    }
                    Button("现在") { time = .now }
                }

                Section {
                    if !item.isExtra && item.state != .skipped {
                        Button { act { DoseActions.skip(item, in: context) } } label: {
                            Label("这次不吃了（跳过）", systemImage: "forward")
                        }
                    }
                    if item.log != nil {
                        Button(role: .destructive) { act { DoseActions.reset(item, in: context) } } label: {
                            Label(item.isExtra ? "删除这条记录" : "撤销记录", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .navigationTitle(item.state.isTaken ? "修改服药时间" : "记录这次服药")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("已服用") { act { DoseActions.setTaken(item, at: time, in: context) } }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(med.tint)
    }

    private func act(_ body: () -> Void) {
        withAnimation(.snappy) { body() }
        dismiss()
    }
}

struct QuickTimeChips: View {
    @Binding var time: Date
    /// (标题, 距现在多少分钟前)
    let options: [(String, Int)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Button(option.0) { time = Date.now.addingTimeInterval(TimeInterval(-option.1 * 60)) }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
