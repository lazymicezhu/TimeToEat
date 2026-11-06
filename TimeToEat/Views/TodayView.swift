import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.createdAt) private var meds: [Medication]
    @Query private var logs: [DoseLog]
    @ObservedObject private var notifier = NotificationManager.shared
    @State private var showAdd = false
    @State private var showRecord = LaunchOptions.openRecord
    @State private var editing: DoseEvent?
    @State private var deleting: DoseEvent?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let now = timeline.date
                let nexts = DoseEngine.nextDoses(meds, logs: logs, now: now)
                let events = DoseEngine.events(on: now, logs: logs)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if meds.isEmpty {
                            emptyState
                        } else {
                            if !nexts.isEmpty { NextDoseCard(nexts: nexts, now: now) }

                            Button { showRecord = true } label: {
                                Label("记录一次服药", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.roundedRectangle(radius: 16))

                            if notifier.status == .notDetermined || notifier.status == .denied {
                                NotificationPrompt(denied: notifier.status == .denied)
                            }

                            records(events)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("今天")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("添加药品")
                }
            }
            .sheet(isPresented: $showAdd) { MedicationEditView(medication: nil) }
            .sheet(isPresented: $showRecord) { RecordDoseSheet() }
            .sheet(item: $editing) { RecordDoseSheet(event: $0) }
            .confirmationDialog("删除这次服药记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let deleting { withAnimation { DoseActions.delete(deleting, in: context) } }
                    deleting = nil
                }
            }
        }
    }

    @ViewBuilder
    private func records(_ events: [DoseEvent]) -> some View {
        let total = events.reduce(0) { $0 + $1.logs.count }
        HStack(alignment: .firstTextBaseline) {
            Text("今天的服药记录").font(.title3.bold())
            Spacer()
            if total > 0 {
                Text("共 \(total) 次").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)

        if events.isEmpty {
            Text("今天还没有记录。吃完药点上面的「记录一次服药」，填上吃药的时间就行。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            ForEach(DayPeriod.group(events)) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Label(group.period.title, systemImage: group.period.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    ForEach(group.events) { event in
                        EventRow(event: event)
                            .onTapGesture { editing = event }
                            .contextMenu {
                                Button { editing = event } label: { Label("修改", systemImage: "pencil") }
                                Button(role: .destructive) { deleting = event } label: { Label("删除", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("还没有添加药品").font(.headline)
            Text("添加你常吃的药，设好两次之间至少隔多久。每次吃完记一下，就会告诉你下次最早什么时候能吃。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Label("添加药品", systemImage: "plus").padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// 顶部卡片：下次最早什么时候可以吃
private struct NextDoseCard: View {
    let nexts: [NextDose]
    let now: Date

    var body: some View {
        let groups = DoseEngine.groups(nexts, now: now)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("下次最早可以吃").font(.footnote.weight(.semibold))
                Spacer()
                Text(Theme.dayTitle(now)).font(.footnote.weight(.medium))
            }
            .opacity(0.85)

            if let first = groups.first { headline(first) }

            if groups.count > 1 {
                Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
                VStack(spacing: 10) {
                    ForEach(groups.dropFirst()) { row($0) }
                }
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.25), radius: 16, y: 8)
    }

    @ViewBuilder
    private func headline(_ g: NextGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if g.ready {
                Text("现在就可以吃")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            } else if let earliest = g.earliest {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ScheduleMath.dayPrefix(earliest, now: now))
                        .font(.headline)
                        .opacity(0.9)
                    Text(ScheduleMath.format(ScheduleMath.minute(of: earliest)))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("以后")
                        .font(.headline)
                        .opacity(0.9)
                }
            }
            Text(g.names)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Group {
                if let earliest = g.earliest, !g.ready {
                    Text("还要等 \(ScheduleMath.remaining(until: earliest, now: now))")
                } else if let last = g.lastTaken {
                    Text("距上次服药已过 \(ScheduleMath.elapsed(since: last, now: now))")
                } else {
                    Text("还没有服药记录")
                }
            }
            .font(.subheadline.weight(.medium))
            .opacity(0.9)
        }
    }

    private func row(_ g: NextGroup) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(g.names)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            if g.ready {
                Text("现在可以吃").font(.subheadline.weight(.semibold))
            } else if let earliest = g.earliest {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(ScheduleMath.clock(earliest, now: now)) 以后")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("还要 \(ScheduleMath.remaining(until: earliest, now: now))")
                        .font(.caption)
                        .opacity(0.85)
                }
            }
        }
    }
}

private struct NotificationPrompt: View {
    let denied: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(denied ? "通知已关闭" : "开启服药提醒").font(.subheadline.weight(.semibold))
                Text(denied ? "在设置里打开通知，到时间才能提醒你" : "到了最早可以吃的时间就通知你")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(denied ? "去设置" : "开启") {
                Task {
                    let manager = NotificationManager.shared
                    if denied {
                        manager.openSystemSettings()
                    } else if await manager.requestAuthorizationIfNeeded() {
                        manager.rescheduleAll(Persistence.container.mainContext)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
