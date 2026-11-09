import SwiftData
import SwiftUI

struct DayStat: Identifiable {
    let day: Date
    let events: [DoseEvent]

    var id: Date { day }
    var doses: Int { events.reduce(0) { $0 + $1.logs.count } }

    /// "甲硝唑 3 · 阿莫西林 3 · 依托考昔 1"
    var perMedication: String {
        let meds = events.flatMap(\.medications)
        var counts: [UUID: (Medication, Int)] = [:]
        for m in meds { counts[m.id] = (m, (counts[m.id]?.1 ?? 0) + 1) }
        return counts.values
            .sorted { $0.0.createdAt < $1.0.createdAt }
            .map { "\($0.0.name) \($0.1)" }
            .joined(separator: " · ")
    }
}

struct HistoryView: View {
    @Query private var logs: [DoseLog]

    private var stats: [DayStat] {
        let cal = Calendar.current
        let today = ScheduleMath.doseDay(of: .now)
        return (0..<30).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayStat(day: day, events: DoseEngine.events(on: day, logs: logs))
        }
    }

    var body: some View {
        NavigationStack {
            let stats = stats
            List {
                Section { WeekSummary(stats: Array(stats.prefix(7).reversed())) }
                Section("每日记录") {
                    let days = stats.filter { $0.doses > 0 }
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

    private var total: Int { stats.reduce(0) { $0 + $1.doses } }
    private var activeDays: Int { stats.filter { $0.doses > 0 }.count }
    private var maxDoses: Int { max(1, stats.map(\.doses).max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("近 7 天服药").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(total)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                        Text("次").font(.headline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("有记录").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(activeDays) 天").font(.title3.bold())
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats) { stat in
                    VStack(spacing: 6) {
                        Text(stat.doses > 0 ? "\(stat.doses)" : " ")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                if stat.doses > 0 {
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(height: max(8, geo.size.height * Double(stat.doses) / Double(maxDoses)))
                                }
                            }
                        }
                        .frame(height: 80)
                        Text(ScheduleMath.isDoseToday(stat.day) ? "今" : stat.day.formatted(.dateTime.weekday(.narrow).locale(Theme.zh)))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ScheduleMath.isDoseToday(stat.day) ? Color.accentColor : .secondary)
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
            Text("\(stat.doses)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(ScheduleMath.isDoseToday(stat.day) ? "今天" : Theme.dayTitle(stat.day))
                    .font(.body.weight(.medium))
                Text(stat.perMedication)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(stat.events.count) 回")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

struct DayDetailView: View {
    let day: Date
    @Query private var logs: [DoseLog]
    @State private var editing: DoseEvent?
    @State private var showRecord = false

    var body: some View {
        let events = DoseEngine.events(on: day, logs: logs)
        ScrollView {
            VStack(spacing: 10) {
                ForEach(events) { event in
                    EventRow(event: event).onTapGesture { editing = event }
                }
                if events.isEmpty {
                    Text("这天没有服药记录").foregroundStyle(.secondary).padding(.top, 40)
                }
                Text("点记录可以修改时间或删除，右上角 + 可以补记")
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
        .sheet(item: $editing) { RecordDoseSheet(event: $0) }
        .sheet(isPresented: $showRecord) {
            RecordDoseSheet(initialTime: ScheduleMath.isDoseToday(day) ? .now : ScheduleMath.date(minute: 12 * 60, on: day))
        }
    }
}
