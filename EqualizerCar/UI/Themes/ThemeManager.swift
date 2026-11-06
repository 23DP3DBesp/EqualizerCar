import Combine
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, day, night
    var id: String { rawValue }
    var title: String { switch self { case .system: "Как в системе"; case .day: "День"; case .night: "Ночь" } }
    var icon: String { switch self { case .system: "circle.lefthalf.filled"; case .day: "sun.max"; case .night: "moon" } }
    var colorScheme: ColorScheme? { switch self { case .system: nil; case .day: .light; case .night: .dark } }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet { userDefaults.set(appearance.rawValue, forKey: "appearance.mode") }
    }
    @Published var systemColorScheme: ColorScheme = .light
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
        appearance = AppAppearance(rawValue: userDefaults.string(forKey: "appearance.mode") ?? "night") ?? .system
        if !userDefaults.bool(forKey: "studioWhiteMigration") {
            userDefaults.set(AppTheme.liquidGlassDark.id, forKey: Keys.selectedThemeID)
            userDefaults.set(true, forKey: "studioWhiteMigration")
        }
        var initialID = userDefaults.string(forKey: Keys.selectedThemeID) ?? AppTheme.studio.id
        if !userDefaults.bool(forKey: "studioDesignMigration") {
            if initialID == AppTheme.liquidGlassDark.id { initialID = AppTheme.studio.id }
            userDefaults.set(initialID, forKey: Keys.selectedThemeID)
            userDefaults.set(true, forKey: "studioDesignMigration")
        }
        selectedThemeID = initialID
        if let data = userDefaults.data(forKey: Keys.customTheme),
           let decodedTheme = try? JSONDecoder().decode(AppTheme.self, from: data) {
            customTheme = decodedTheme
        } else {
            customTheme = AppTheme(
                id: "custom-ambient",
                displayName: "Своя тема",
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
        let palette = availableThemes.first { $0.id == selectedThemeID } ?? AppTheme.liquidGlassDark
        return palette.resolved(dark: (appearance.colorScheme ?? systemColorScheme) == .dark)
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
    static let defaultValue = AppTheme.studio
}

extension EnvironmentValues {
    var carAmbientTheme: AppTheme {
        get { self[CarAmbientThemeKey.self] }
        set { self[CarAmbientThemeKey.self] = newValue }
    }
}

struct CarAmbientThemeModifier: ViewModifier {
    @ObservedObject var manager: ThemeManager
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .environment(\.carAmbientTheme, manager.current)
            .environmentObject(manager)
            .tint(manager.current.accent)
            .preferredColorScheme(manager.appearance.colorScheme)
            .onAppear { manager.systemColorScheme = systemScheme }
            .onChange(of: systemScheme) { _, scheme in manager.systemColorScheme = scheme }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: manager.appearance)
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
