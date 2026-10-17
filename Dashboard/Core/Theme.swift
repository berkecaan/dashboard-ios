import SwiftUI

enum Theme {
    static let cyan = Color(red: 0.25, green: 0.82, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.25)
}

extension EnvironmentValues {
    @Entry var dashAccent: Color = Theme.cyan
}

extension View {
    /// Liquid Glass panel (iOS 26).
    func glassPanel(cornerRadius: CGFloat = 32) -> some View {
        self
            .glassEffect(.regular.tint(Color.black.opacity(0.25)),
                         in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }
}

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 54
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint ?? .white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
    }
}

enum Fmt {
    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return "\(max(10, Int((meters / 10).rounded()) * 10)) m" }
        return String(format: "%.1f km", meters / 1000)
    }

    static func duration(_ seconds: Double) -> String {
        let m = max(1, Int((seconds / 60).rounded()))
        return m >= 60 ? "\(m / 60) sa \(m % 60) dk" : "\(m) dk"
    }
}

