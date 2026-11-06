import SwiftData
import SwiftUI

/// 记录 / 修改一次服药：什么时候吃的 + 吃了哪几种药
struct RecordDoseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.createdAt) private var meds: [Medication]
    @Query private var logs: [DoseLog]

    let event: DoseEvent?
    @State private var time: Date
    @State private var selected: Set<UUID>
    @State private var confirmDelete = false

    init(event: DoseEvent? = nil, initialTime: Date = .now) {
        self.event = event
        _time = State(initialValue: event?.time ?? initialTime)
        _selected = State(initialValue: Set(event?.medications.map(\.id) ?? []))
    }

    private var choices: [Medication] { meds.filter { $0.isActive || selected.contains($0.id) } }

    /// 计算间隔时不算正在修改的这条记录
    private var otherLogs: [DoseLog] {
        guard let event else { return logs }
        let ids = Set(event.logs.map(\.persistentModelID))
        return logs.filter { !ids.contains($0.persistentModelID) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("什么时候吃的") {
                    DatePicker("服药时间", selection: $time, in: ...Date.now.addingTimeInterval(300),
                               displayedComponents: [.date, .hourAndMinute])
                    if event == nil {
                        QuickTimeChips(time: $time, options: [
                            ("现在", 0), ("15 分钟前", 15), ("30 分钟前", 30), ("1 小时前", 60),
                        ])
                    }
                }

                Section {
                    if choices.isEmpty {
                        Text("还没有药品，先去「我的药」添加").foregroundStyle(.secondary)
                    }
                    let others = otherLogs
                    ForEach(choices) { med in
                        medRow(med, logs: others)
                    }
                } header: {
                    Text("吃了哪些药（可多选）")
                } footer: {
                    Text("如果离上次吃还没到间隔时间，会用橙色提示，但仍然可以记录。")
                }

                if event != nil {
                    Section {
                        Button("删除这次记录", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(event == nil ? "记录服药" : "修改记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(event == nil ? "记录" : "保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(selected.isEmpty)
                }
            }
            .confirmationDialog("删除这次服药记录？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let event { withAnimation { DoseActions.delete(event, in: context) } }
                    dismiss()
                }
            }
        }
    }

    private func medRow(_ med: Medication, logs: [DoseLog]) -> some View {
        let isOn = selected.contains(med.id)
        let next = DoseEngine.next(for: med, logs: logs, now: time)
        let tooEarly = !next.isReady(at: time)
        return Button {
            if isOn { selected.remove(med.id) } else { selected.insert(med.id) }
        } label: {
            HStack(spacing: 12) {
                MedIcon(iconName: med.iconName, color: med.tint, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name).font(.body.weight(.medium))
                    if tooEarly, let earliest = next.earliest {
                        Text("还没到间隔，最早 \(ScheduleMath.clock(earliest, now: time))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    } else if let last = next.last {
                        Text("上次 \(ScheduleMath.clock(last, now: time)) · \(med.ruleSummary)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(med.ruleSummary).font(.caption).foregroundStyle(.secondary)
                    }
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

    private func save() {
        let chosen = meds.filter { selected.contains($0.id) }
        withAnimation(.snappy) {
            if let event {
                DoseActions.update(event, time: time, medications: chosen, in: context)
            } else {
                DoseActions.record(chosen, at: time, in: context)
            }
        }
        let ctx = context
        Task {
            if chosen.contains(where: \.remindersOn) {
                await NotificationManager.shared.requestAuthorizationIfNeeded()
            }
            NotificationManager.shared.rescheduleAll(ctx)
        }
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
