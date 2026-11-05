import SwiftData
import SwiftUI

struct MedicationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let medication: Medication?
    @State private var draft: MedicationDraft
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    init(medication: Medication?) {
        self.medication = medication
        _draft = State(initialValue: medication.map(MedicationDraft.init) ?? MedicationDraft())
    }

    private var tint: Color { (MedColor(rawValue: draft.colorName) ?? .teal).color }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                noteSection
                appearanceSection
                scheduleSection
                optionsSection
                if medication != nil {
                    Section {
                        Button("删除这个药", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(medication == nil ? "添加药品" : "编辑药品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!draft.isValid)
                }
            }
            .confirmationDialog("删除后，这个药的服药记录也会一起删除。", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) { delete() }
            }
            .onAppear { if medication == nil { nameFocused = true } }
        }
        .tint(tint)
    }

    // MARK: Sections

    private var basicSection: some View {
        Section {
            HStack(spacing: 14) {
                MedIcon(iconName: draft.iconName, color: tint, size: 52)
                TextField("药品名称，如：阿莫西林", text: $draft.name)
                    .font(.title3.weight(.semibold))
                    .focused($nameFocused)
                    .submitLabel(.done)
            }
            .padding(.vertical, 4)
            LabeledContent("每次剂量") {
                TextField("如 1 片、5 ml", text: $draft.dosage)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var noteSection: some View {
        Section("服用说明") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Theme.noteTags, id: \.self) { tag in
                        let selected = draft.note == tag
                        Button {
                            draft.note = selected ? "" : tag
                        } label: {
                            Text(tag)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .foregroundStyle(selected ? .white : .primary)
                                .background(selected ? tint : Color(.tertiarySystemFill), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            TextField("其他备注（可选）", text: $draft.note)
        }
    }

    private var appearanceSection: some View {
        Section("图标和颜色") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Theme.icons, id: \.self) { icon in
                        Button { draft.iconName = icon } label: {
                            MedIcon(iconName: icon, color: draft.iconName == icon ? tint : .secondary, size: 42)
                                .overlay {
                                    if draft.iconName == icon {
                                        RoundedRectangle(cornerRadius: 42 * 0.32, style: .continuous).strokeBorder(tint, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MedColor.allCases) { c in
                        Button { draft.colorName = c.rawValue } label: {
                            Circle().fill(c.color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if draft.colorName == c.rawValue {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            Picker("方式", selection: $draft.mode) {
                ForEach(ScheduleMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowSeparator(.hidden)

            if draft.mode == .timesPerDay {
                Stepper(value: countBinding, in: 1...8) {
                    Text("每天 ").foregroundStyle(.secondary) + Text("\(draft.times.count)").bold() + Text(" 次").foregroundStyle(.secondary)
                }
                ForEach(Array(draft.times.indices), id: \.self) { i in
                    DatePicker("第 \(i + 1) 次", selection: timeBinding(index: i), displayedComponents: .hourAndMinute)
                }
            } else {
                Stepper(value: $draft.intervalHours, in: 1...24) {
                    Text("每隔 ").foregroundStyle(.secondary) + Text("\(draft.intervalHours)").bold() + Text(" 小时一次").foregroundStyle(.secondary)
                }
                DatePicker("第一次", selection: minuteBinding($draft.intervalStart), displayedComponents: .hourAndMinute)
                DatePicker("最晚不超过", selection: minuteBinding($draft.intervalEnd), displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("怎么吃")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                if draft.dailyMinutes.isEmpty {
                    Text("请设置至少一个服药时间")
                } else {
                    Text("每天会在这些时间提醒你（共 \(draft.dailyMinutes.count) 次）：")
                    FlowLayout(spacing: 6) {
                        ForEach(draft.dailyMinutes, id: \.self) { TimeChip(minute: $0, color: tint) }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle("到点提醒", isOn: $draft.remindersOn)
            Toggle("正在服用", isOn: $draft.isActive)
        } footer: {
            Text("暂停后不会出现在「今天」的列表里，也不会再提醒。")
        }
    }

    // MARK: Bindings

    private var countBinding: Binding<Int> {
        Binding(
            get: { draft.times.count },
            set: { newCount in
                withAnimation { draft.times = ScheduleMath.presetTimes(count: newCount) }
            })
    }

    private func timeBinding(index: Int) -> Binding<Date> {
        Binding(
            get: { ScheduleMath.date(minute: index < draft.times.count ? draft.times[index] : 0, on: .now) },
            set: { date in
                guard index < draft.times.count else { return }
                draft.times[index] = ScheduleMath.minute(of: date)
            })
    }

    private func minuteBinding(_ value: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { ScheduleMath.date(minute: value.wrappedValue, on: .now) },
            set: { value.wrappedValue = ScheduleMath.minute(of: $0) })
    }

    // MARK: Actions

    private func save() {
        let med: Medication
        if let medication {
            med = medication
        } else {
            med = Medication(name: draft.name)
            context.insert(med)
        }
        draft.apply(to: med)
        try? context.save()
        let wantsReminders = draft.remindersOn
        let ctx = context
        Task {
            if wantsReminders { await NotificationManager.shared.requestAuthorizationIfNeeded() }
            NotificationManager.shared.rescheduleAll(ctx)
        }
        dismiss()
    }

    private func delete() {
        guard let medication else { return }
        context.delete(medication)
        try? context.save()
        NotificationManager.shared.rescheduleAll(context)
        dismiss()
    }
}
