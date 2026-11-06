import SwiftUI

private func readyFirst(_ nexts: [NextDose], now: Date) -> [NextDose] {
    nexts.filter { $0.isReady(at: now) } + nexts.filter { !$0.isReady(at: now) }
}

private func lastText(_ n: NextDose, now: Date) -> String {
    guard let last = n.last else { return "还没吃过" }
    return "上次 \(ScheduleMath.clock(last, now: now))"
}

/// 今天页顶部卡片：每种药一行，显示现在能不能吃、还要等多久，以及间隔进度
struct NextDoseCard: View {
    let nexts: [NextDose]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("现在能吃吗").font(.title3.bold())
                Spacer()
                Text(Theme.dayTitle(now)).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.bottom, 14)

            let list = readyFirst(nexts, now: now)
            ForEach(Array(list.enumerated()), id: \.element.id) { i, n in
                if i > 0 { Divider().padding(.vertical, 12) }
                row(n)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row(_ n: NextDose) -> some View {
        let med = n.medication
        let ready = n.isReady(at: now)
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                MedIcon(iconName: med.iconName, color: med.tint, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name).font(.headline)
                    Text(lastText(n, now: now)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if ready {
                    Label("可以吃", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.green, in: Capsule())
                } else if let e = n.earliest {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(ScheduleMath.shortClock(e, now: now)) 后")
                            .font(.headline.monospacedDigit())
                        Text("还要 \(ScheduleMath.remaining(until: e, now: now))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
            if !ready {
                ProgressView(value: n.progress(at: now)).tint(med.tint)
            }
        }
    }
}
