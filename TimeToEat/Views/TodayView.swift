import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.createdAt) private var meds: [Medication]
    @Query private var logs: [DoseLog]
    @ObservedObject private var notifier = NotificationManager.shared
    @State private var showAdd = false
    @State private var showRecord = LaunchOptions.openRecord
    @State private var selected: DoseItem?
    @State private var successTick = 0

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let now = timeline.date
                let items = DoseEngine.doses(on: now, medications: meds, logs: logs, now: now)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SummaryCard(items: items, now: now)

                        if !meds.isEmpty {
                            Button { showRecord = true } label: {
                                Label("记录一次服药", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .buttonBorderShape(.roundedRectangle(radius: 16))
                        }

                        if notifier.status == .notDetermined || notifier.status == .denied, !meds.isEmpty {
                            NotificationPrompt(denied: notifier.status == .denied)
                        }

                        if items.isEmpty {
                            emptyState
                        } else {
                            ForEach(DayPeriod.group(items, descending: true)) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Label(group.period.title, systemImage: group.period.icon)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    ForEach(group.items) { item in
                                        DoseRow(item: item, now: now, onToggle: { toggle(item) }, onOpen: { selected = item })
                                            .contextMenu { menu(for: item) }
                                    }
                                }
                            }
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
            .sheet(item: $selected) { DoseDetailSheet(item: $0) }
            .sensoryFeedback(.success, trigger: successTick)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text(meds.isEmpty ? "还没有添加药品" : "今天没有服药安排")
                .font(.headline)
            Text("添加你常吃的药，设置每天几次或隔多久一次，到点就会提醒你。")
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

    @ViewBuilder
    private func menu(for item: DoseItem) -> some View {
        Button { selected = item } label: { Label("修改服药时间", systemImage: "clock") }
        if !item.state.isTaken {
            Button { toggle(item) } label: { Label("标记已服用", systemImage: "checkmark.circle") }
        }
        if item.state != .skipped && !item.isExtra {
            Button { withAnimation { DoseActions.skip(item, in: context) } } label: { Label("跳过这次", systemImage: "forward") }
        }
        if item.log != nil {
            Button(role: .destructive) { withAnimation { DoseActions.reset(item, in: context) } } label: {
                Label("撤销记录", systemImage: "arrow.uturn.backward")
            }
        }
    }

    private func toggle(_ item: DoseItem) {
        let wasTaken = item.state.isTaken
        withAnimation(.snappy) { DoseActions.toggleTaken(item, in: context) }
        if !wasTaken { successTick += 1 }
    }
}

private struct SummaryCard: View {
    let items: [DoseItem]
    let now: Date

    private var taken: Int { items.filter { $0.state.isTaken }.count }
    private var missed: Int { items.filter { $0.state == .missed }.count }
    private var next: DoseItem? { items.first { $0.state.isPending } }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: items.isEmpty ? 0 : Double(taken) / Double(items.count), lineWidth: 9)
                VStack(spacing: 0) {
                    Text("\(taken)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("/ \(items.count)")
                        .font(.caption.weight(.medium))
                        .opacity(0.8)
                }
                .monospacedDigit()
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 6) {
                Text(Theme.dayTitle(now))
                    .font(.footnote.weight(.medium))
                    .opacity(0.85)
                content
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.25), radius: 16, y: 8)
    }

    @ViewBuilder
    private var content: some View {
        if let next {
            let mins = Int(next.scheduledAt.timeIntervalSince(now) / 60)
            Text("下一次 \(ScheduleMath.format(next.minute))")
                .font(.caption.weight(.semibold))
                .opacity(0.85)
            Text(next.medication.name)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            let dosage = next.medication.dosage.isEmpty ? "" : " · \(next.medication.dosage)"
            Text(next.state == .due ? "现在该吃了\(dosage)" : "还有 \(ScheduleMath.duration(mins))\(dosage)")
                .font(.subheadline.weight(.medium))
                .opacity(0.9)
        } else if items.isEmpty {
            Text("今天没有服药安排").font(.title3.bold())
        } else if taken == items.count {
            Text("今天的药都吃完啦").font(.title3.bold())
            Text("继续保持 👏").font(.subheadline).opacity(0.9)
        } else {
            Text("今天的提醒都结束了").font(.title3.bold())
            if missed > 0 {
                Text("有 \(missed) 次还没记录，记得补上").font(.subheadline).opacity(0.9)
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
                Text(denied ? "在设置里打开通知，才能准时提醒你" : "到点推送通知，可直接点「已服用」")
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
