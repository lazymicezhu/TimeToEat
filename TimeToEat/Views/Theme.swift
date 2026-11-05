import SwiftUI

enum MedColor: String, CaseIterable, Identifiable {
    case teal, green, blue, indigo, purple, pink, coral, orange, yellow

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .teal: return Color(red: 0.12, green: 0.62, blue: 0.58)
        case .green: return Color(red: 0.30, green: 0.68, blue: 0.36)
        case .blue: return Color(red: 0.22, green: 0.50, blue: 0.92)
        case .indigo: return Color(red: 0.36, green: 0.38, blue: 0.85)
        case .purple: return Color(red: 0.60, green: 0.38, blue: 0.85)
        case .pink: return Color(red: 0.90, green: 0.36, blue: 0.58)
        case .coral: return Color(red: 0.93, green: 0.40, blue: 0.36)
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .yellow: return Color(red: 0.88, green: 0.66, blue: 0.10)
        }
    }
}

enum Theme {
    static let icons = ["pills.fill", "capsule.fill", "cross.vial.fill", "drop.fill", "syringe.fill",
                        "bandage.fill", "sun.max.fill", "moon.zzz.fill", "leaf.fill", "heart.fill", "testtube.2"]
    static let noteTags = ["饭前", "饭后", "随餐", "空腹", "睡前"]

    static let gradient = LinearGradient(
        colors: [Color(red: 0.13, green: 0.66, blue: 0.60), Color(red: 0.09, green: 0.47, blue: 0.52)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let zh = Locale(identifier: "zh_CN")

    static func dayTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().weekday(.wide).locale(zh))
    }
}

extension Medication {
    var tint: Color { (MedColor(rawValue: colorName) ?? .teal).color }
}

struct MedIcon: View {
    let iconName: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var track: Color = .white.opacity(0.25)
    var tint: Color = .white

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(duration: 0.5), value: progress)
    }
}

struct TimeChip: View {
    let minute: Int
    let color: Color

    var body: some View {
        Text(ScheduleMath.format(minute))
            .font(.caption.weight(.medium).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxW {
                x = 0; y += rowH + spacing; rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
