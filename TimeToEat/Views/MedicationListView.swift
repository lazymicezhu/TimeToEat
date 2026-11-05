import SwiftData
import SwiftUI

struct MedicationListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.createdAt) private var meds: [Medication]
    @State private var editing: Medication?
    @State private var showAdd = LaunchOptions.openAdd

    var body: some View {
        NavigationStack {
            Group {
                if meds.isEmpty {
                    ContentUnavailableView {
                        Label("还没有添加药品", systemImage: "pills")
                    } description: {
                        Text("把你常吃的药加进来，按时提醒你")
                    } actions: {
                        Button("添加药品") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    List {
                        ForEach(meds) { med in
                            Section {
                                Button { editing = med } label: { MedicationRow(med: med, now: timeline.date) }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) { delete(med) } label: { Label("删除", systemImage: "trash") }
                                        Button { toggleActive(med) } label: {
                                            Label(med.isActive ? "暂停" : "恢复", systemImage: med.isActive ? "pause" : "play")
                                        }
                                        .tint(.gray)
                                    }
                            }
                        }
                    }
                    .listSectionSpacing(12)
                    }
                }
            }
            .navigationTitle("我的药")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { MedicationEditView(medication: $0) }
            .sheet(isPresented: $showAdd) { MedicationEditView(medication: nil) }
        }
    }

    private func delete(_ med: Medication) {
        withAnimation { context.delete(med) }
        try? context.save()
        NotificationManager.shared.rescheduleAll(context)
    }

    private func toggleActive(_ med: Medication) {
        med.isActive.toggle()
        try? context.save()
        NotificationManager.shared.rescheduleAll(context)
    }
}

private struct MedicationRow: View {
    let med: Medication
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MedIcon(iconName: med.iconName, color: med.tint, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(med.name).font(.headline)
                    if !med.isActive {
                        Text("已暂停")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    if !med.remindersOn {
                        Image(systemName: "bell.slash").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !med.detailLine.isEmpty {
                    Text(med.detailLine).font(.subheadline).foregroundStyle(.secondary)
                }
                lastDoseLine
                Label(scheduleText, systemImage: med.mode == .interval ? "timer" : "repeat")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(med.tint)
                FlowLayout(spacing: 6) {
                    ForEach(med.dailyMinutes, id: \.self) { TimeChip(minute: $0, color: med.tint) }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .opacity(med.isActive ? 1 : 0.6)
    }

    @ViewBuilder
    private var lastDoseLine: some View {
        if let last = med.lastTaken(before: now) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(med.tint)
                (Text("距上次服药 ") + Text(ScheduleMath.elapsed(since: last, now: now)).bold())
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(med.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("上次：\(ScheduleMath.clock(last))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label("还没有服药记录", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var scheduleText: String {
        if med.mode == .interval {
            return "\(med.scheduleSummary)（\(ScheduleMath.format(med.intervalStart))–\(ScheduleMath.format(med.intervalEnd))）"
        }
        return med.scheduleSummary
    }
}
