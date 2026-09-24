import SwiftUI
import CinderCore

extension Color {
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xE3AD59
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}
private struct ThemeKey: EnvironmentKey { static let defaultValue: ThemeDocument? = nil }
extension EnvironmentValues {
    var cinderTheme: ThemeDocument? {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// Resolve the entire button palette in SwiftUI, avoiding a second native bezel transition.
struct CinderButtonStyle: ButtonStyle {
    @Environment(\.cinderTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var size
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        let foreground = theme.map { Color(hex: $0.colors[prominent ? "selection.foreground" : "control.foreground"]!) } ?? (prominent ? Color.white : Color.primary)
        let background = theme.map { Color(hex: $0.colors[prominent ? "selection.background" : "control.background"]!) } ?? (prominent ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        return configuration.label
            .padding(.horizontal, size == .small ? 6 : 12)
            .padding(.vertical, size == .large ? 8 : 5)
            .foregroundStyle(foreground)
            .background(RoundedRectangle(cornerRadius: 7).fill(background))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(foreground.opacity(configuration.isPressed ? 0.45 : 0.18)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
    }
}
