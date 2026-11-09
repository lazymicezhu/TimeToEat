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

/// 「跨天凌晨」印章：过了 0 点、算在前一天的那次服药
struct CrossDayStamp: View {
    private let red = Color(red: 0.84, green: 0.22, blue: 0.18)

    var body: some View {
        Text("跨天凌晨")
            .font(.system(size: 11, weight: .heavy))
            .tracking(1)
            .foregroundStyle(red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(red, lineWidth: 1.5))
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(red.opacity(0.6), lineWidth: 0.8))
            .rotationEffect(.degrees(-12))
            .opacity(0.9)
            .accessibilityLabel("跨天凌晨，算在前一天")
    }
}
