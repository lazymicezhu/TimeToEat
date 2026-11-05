import SwiftData
import SwiftUI

struct DayStat: Identifiable {
    let day: Date
    let items: [DoseItem]
    var id: Date { day }
    var total: Int { items.count }
    var taken: Int { items.filter { $0.state.isTaken }.count }
    var missed: Int { items.filter { $0.state == .missed }.count }
    var settled: Int { items.filter { !$0.state.isPending }.count }
    var ratio: Double { total == 0 ? 0 : Double(taken) / Double(total) }
}

struct HistoryView: View {
    @Query private var meds: [Medication]
    @Query private var logs: [DoseLog]

    private var stats: [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<14).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayStat(day: day, items: DoseEngine.doses(on: day, medications: meds, logs: logs))
        }
    }

    var body: some View {
        NavigationStack {
            let stats = stats
            List {
                Section { WeekSummary(stats: Array(stats.prefix(7).reversed())) }
                Section("每日记录") {
                    let days = stats.filter { $0.total > 0 }
                    if days.isEmpty {
                        Text("还没有记录").foregroundStyle(.secondary)
                    }
                    ForEach(days) { stat in
                        NavigationLink {
                            DayDetailView(day: stat.day)
                        } label: {
                            DayRowView(stat: stat)
                        }
                    }
                }
            }
            .navigationTitle("记录")
        }
    }
}

private struct WeekSummary: View {
    let stats: [DayStat]

    private var rate: Int {
        let settled = stats.reduce(0) { $0 + $1.settled }
        let taken = stats.reduce(0) { $0 + $1.taken }
        return settled == 0 ? 0 : Int((Double(taken) / Double(settled) * 100).rounded())
    }
    private var missed: Int { stats.reduce(0) { $0 + $1.missed } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("近 7 天按时服药").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(rate)%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("漏服").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(missed) 次").font(.title3.bold()).foregroundStyle(missed > 0 ? .orange : .primary)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats) { stat in
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                if stat.total > 0 {
                                    Capsule()
                                        .fill(stat.ratio >= 1 ? Color.accentColor : Color.accentColor.opacity(0.6))
                                        .frame(height: max(6, geo.size.height * stat.ratio))
                                }
                            }
                        }
                        .frame(height: 80)
                        Text(Calendar.current.isDateInToday(stat.day) ? "今" : stat.day.formatted(.dateTime.weekday(.narrow).locale(Theme.zh)))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Calendar.current.isDateInToday(stat.day) ? Color.accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DayRowView: View {
    let stat: DayStat

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: stat.ratio, lineWidth: 5, track: Color(.tertiarySystemFill), tint: .accentColor)
                if stat.taken == stat.total {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(Calendar.current.isDateInToday(stat.day) ? "今天" : Theme.dayTitle(stat.day))
                    .font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(stat.taken)/\(stat.total)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts = ["已服 \(stat.taken) 次"]
        if stat.missed > 0 { parts.append("漏服 \(stat.missed) 次") }
        return parts.joined(separator: " · ")
    }
}

struct DayDetailView: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Query private var meds: [Medication]
    @Query private var logs: [DoseLog]
    @State private var selected: DoseItem?
    @State private var showRecord = false

    var body: some View {
        let items = DoseEngine.doses(on: day, medications: meds, logs: logs)
        ScrollView {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    DoseRow(item: item, now: .now,
                            onToggle: { withAnimation(.snappy) { DoseActions.toggleTaken(item, in: context) } },
                            onOpen: { selected = item })
                }
                Text("点右侧圆圈补记或撤销，点卡片可修改服药时间")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Theme.dayTitle(day))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showRecord = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("补记服药")
            }
        }
        .sheet(item: $selected) { DoseDetailSheet(item: $0) }
        .sheet(isPresented: $showRecord) {
            RecordDoseSheet(initialTime: Calendar.current.isDateInToday(day) ? .now : ScheduleMath.date(minute: 12 * 60, on: day))
        }
    }
}
