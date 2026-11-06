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
            Stepper(value: $draft.minIntervalMinutes, in: 30...(48 * 60), step: 30) {
                Text("两次至少间隔 ").foregroundStyle(.secondary)
                    + Text(ScheduleMath.duration(draft.minIntervalMinutes)).bold().foregroundStyle(tint)
            }
            Stepper(value: $draft.maxPerDay, in: 1...12) {
                Text("每天最多 ").foregroundStyle(.secondary)
                    + Text("\(draft.maxPerDay)").bold().foregroundStyle(tint)
                    + Text(" 次").foregroundStyle(.secondary)
            }
        } header: {
            Text("服用间隔")
        } footer: {
            Text("每次记录服药后，「今天」页会算出下次最早什么时候能吃；当天吃满次数后，要等到第二天。")
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle("到时间提醒我", isOn: $draft.remindersOn)
            Toggle("正在服用", isOn: $draft.isActive)
        } footer: {
            Text("打开提醒后，到了最早可以吃的时间会推送通知。暂停服用的药不会出现在「今天」的提示里。")
        }
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
