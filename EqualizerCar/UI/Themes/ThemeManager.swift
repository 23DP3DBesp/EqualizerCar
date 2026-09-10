import Combine
import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var selectedThemeID: String
    @Published var customTheme: AppTheme {
        didSet { persistCustomTheme() }
    }

    private let userDefaults: UserDefaults
    private enum Keys {
        static let selectedThemeID = "ambientTheme.selectedThemeID"
        static let customTheme = "ambientTheme.customTheme"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if !userDefaults.bool(forKey: "studioWhiteMigration") {
            userDefaults.set(AppTheme.liquidGlassDark.id, forKey: Keys.selectedThemeID)
            userDefaults.set(true, forKey: "studioWhiteMigration")
        }
        selectedThemeID = userDefaults.string(forKey: Keys.selectedThemeID) ?? AppTheme.liquidGlassDark.id
        if let data = userDefaults.data(forKey: Keys.customTheme),
           let decodedTheme = try? JSONDecoder().decode(AppTheme.self, from: data) {
            customTheme = decodedTheme
        } else {
            customTheme = AppTheme(
                id: "custom-ambient",
                displayName: "Custom Ambient",
                style: .modernGlass,
                accentColor: ThemeColor(red: 1.00, green: 0.58, blue: 0.18),
                secondaryAccentColor: ThemeColor(red: 1.00, green: 0.84, blue: 0.52),
                backgroundColor: ThemeColor(red: 0.045, green: 0.036, blue: 0.030),
                surfaceColor: ThemeColor(red: 0.12, green: 0.09, blue: 0.07, opacity: 0.92),
                glassOpacity: 0.82,
                glassBlur: 14,
                fontDesign: .rounded
            )
        }
    }

    var availableThemes: [AppTheme] {
        AppTheme.presets + [customTheme]
    }

    var current: AppTheme {
        availableThemes.first { $0.id == selectedThemeID } ?? AppTheme.liquidGlassDark
    }

    var isUsingCustomTheme: Bool {
        selectedThemeID == customTheme.id
    }

    func selectTheme(id: String) {
        guard availableThemes.contains(where: { $0.id == id }) else { return }
        selectedThemeID = id
        userDefaults.set(id, forKey: Keys.selectedThemeID)
    }

    func selectTheme(_ theme: AppTheme) {
        selectTheme(id: theme.id)
    }

    func updateCustomAccent(_ color: Color) {
        let accent = ThemeColor.from(color)
        customTheme.accentColor = accent
        customTheme.secondaryAccentColor = accent.lifted(amount: 0.24)
        if !isUsingCustomTheme {
            selectTheme(id: customTheme.id)
        }
    }

    func updateCustomStyle(_ style: AppThemeStyle) {
        customTheme.style = style
        if style == .retroDashboard {
            customTheme.fontDesign = .monospaced
        }
        if !isUsingCustomTheme {
            selectTheme(id: customTheme.id)
        }
    }

    func updateCustomGlass(opacity: Double, blur: Double) {
        customTheme.glassOpacity = min(max(opacity, 0.35), 1)
        customTheme.glassBlur = min(max(blur, 0), 32)
        if !isUsingCustomTheme {
            selectTheme(id: customTheme.id)
        }
    }

    private func persistCustomTheme() {
        guard let data = try? JSONEncoder().encode(customTheme) else { return }
        userDefaults.set(data, forKey: Keys.customTheme)
    }
}

private extension ThemeColor {
    func lifted(amount: Double) -> ThemeColor {
        ThemeColor(
            red: red + (1 - red) * amount,
            green: green + (1 - green) * amount,
            blue: blue + (1 - blue) * amount,
            opacity: opacity
        )
    }
}

private struct CarAmbientThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.liquidGlassDark
}

extension EnvironmentValues {
    var carAmbientTheme: AppTheme {
        get { self[CarAmbientThemeKey.self] }
        set { self[CarAmbientThemeKey.self] = newValue }
    }
}

struct CarAmbientThemeModifier: ViewModifier {
    @ObservedObject var manager: ThemeManager

    func body(content: Content) -> some View {
        content
            .environment(\.carAmbientTheme, manager.current)
            .environmentObject(manager)
            .tint(manager.current.accent)
            .animation(.easeInOut(duration: 0.22), value: manager.current.id)
    }
}

extension View {
    func carAmbientTheme(_ manager: ThemeManager) -> some View {
        modifier(CarAmbientThemeModifier(manager: manager))
    }

    func themedPanel(cornerRadius: CGFloat = 8, interactive: Bool = false) -> some View {
        modifier(ThemedPanelModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    func themedGlow(radius: CGFloat = 14) -> some View {
        modifier(ThemedGlowModifier(radius: radius))
    }
}

private struct ThemedPanelModifier: ViewModifier {
    @Environment(\.carAmbientTheme) private var theme
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

    }
}

private struct ThemedGlowModifier: ViewModifier {
    @Environment(\.carAmbientTheme) private var theme
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.03), radius: min(radius, 4), x: 0, y: 2)
    }
}
