import SwiftUI

struct ThemeColor: Codable, Equatable, Sendable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.opacity = min(max(opacity, 0), 1)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }

    static func from(_ color: Color) -> ThemeColor {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return ThemeColor(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
        #else
        return ThemeColor(red: 1, green: 1, blue: 1)
        #endif
    }
}

enum AppThemeStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case modernGlass
    case retroDashboard
    case minimalist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modernGlass:
            return "Современное стекло"
        case .retroDashboard:
            return "Ретро-панель"
        case .minimalist:
            return "Минимализм"
        }
    }
}

enum AppThemeFontDesign: String, Codable, CaseIterable, Identifiable, Sendable {
    case `default`
    case monospaced
    case rounded

    var id: String { rawValue }

    var swiftUIFontDesign: Font.Design {
        switch self {
        case .default:
            return .default
        case .monospaced:
            return .monospaced
        case .rounded:
            return .rounded
        }
    }
}

struct AppTheme: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var displayName: String
    var style: AppThemeStyle
    var accentColor: ThemeColor
    var secondaryAccentColor: ThemeColor
    var backgroundColor: ThemeColor
    var surfaceColor: ThemeColor
    var glassOpacity: Double
    var glassBlur: Double
    var fontDesign: AppThemeFontDesign

    var accent: Color { accentColor.color }
    var secondaryAccent: Color { secondaryAccentColor.color }
    var isDark: Bool { backgroundColor.red * 0.2126 + backgroundColor.green * 0.7152 + backgroundColor.blue * 0.0722 < 0.4 }
    var background: Color { backgroundColor.color }
    var surface: Color { surfaceColor.color }
    var mutedInk: Color { isDark ? Color(red: 0.557, green: 0.584, blue: 0.639) : Color(white: 0.43) }
    var ink: Color { isDark ? Color(white: 0.97) : Color(white: 0.067) }
    var separator: Color { ink.opacity(isDark ? 0.12 : 0.08) }
    var onAccent: Color {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = linear(accentColor.red) * 0.2126 + linear(accentColor.green) * 0.7152 + linear(accentColor.blue) * 0.0722
        return luminance > 0.179 ? .black : .white
    }
    var screenBackground: LinearGradient {
        LinearGradient(colors: [background, background], startPoint: .top, endPoint: .bottom)
    }

    func resolved(dark: Bool) -> AppTheme {
        var result = self
        result.backgroundColor = dark ? ThemeColor(red: 0.051, green: 0.067, blue: 0.098) : ThemeColor(red: 1, green: 1, blue: 1)
        result.surfaceColor = dark ? ThemeColor(red: 0.082, green: 0.102, blue: 0.141) : ThemeColor(red: 0.96, green: 0.965, blue: 0.97)
        let a = accentColor
        if !dark && a.red * 0.2126 + a.green * 0.7152 + a.blue * 0.0722 > 0.6 {
            result.accentColor = ThemeColor(red: a.red * 0.55, green: a.green * 0.55, blue: a.blue * 0.55)
        }
        if id == Self.liquidGlassDark.id {
            result.accentColor = dark ? ThemeColor(red: 1, green: 0.32, blue: 0.39) : ThemeColor(red: 0.86, green: 0.12, blue: 0.18)
        }
        if id == Self.studio.id {
            result.accentColor = dark ? ThemeColor(red: 0.97, green: 0.97, blue: 0.98) : ThemeColor(red: 0.08, green: 0.10, blue: 0.14)
        }
        result.secondaryAccentColor = result.accentColor
        return result
    }

    var panelTint: Color {
        surface.opacity(glassOpacity)
    }
}

extension AppTheme {
    static let liquidGlassDark = AppTheme(
        id: "liquid-glass-dark",
        displayName: "Студийный красный",
        style: .minimalist,
        accentColor: ThemeColor(red: 0.86, green: 0.12, blue: 0.18),
        secondaryAccentColor: ThemeColor(red: 0.95, green: 0.85, blue: 0.86),
        backgroundColor: ThemeColor(red: 0.035, green: 0.035, blue: 0.035),
        surfaceColor: ThemeColor(red: 0.10, green: 0.10, blue: 0.10, opacity: 0.94),
        glassOpacity: 0.92,
        glassBlur: 18,
        fontDesign: .default
    )

    static let studio = AppTheme(
        id: "studio-monochrome", displayName: "Студия", style: .minimalist,
        accentColor: ThemeColor(red: 0.97, green: 0.97, blue: 0.98),
        secondaryAccentColor: ThemeColor(red: 0.75, green: 0.78, blue: 0.84),
        backgroundColor: ThemeColor(red: 0.051, green: 0.067, blue: 0.098),
        surfaceColor: ThemeColor(red: 0.082, green: 0.102, blue: 0.141),
        glassOpacity: 1, glassBlur: 0, fontDesign: .default
    )
    static let presets: [AppTheme] = [
        studio,
        liquidGlassDark,
        AppTheme(
            id: "cyber-cyan",
            displayName: "Кибер-голубой",
            style: .modernGlass,
            accentColor: ThemeColor(red: 0.00, green: 0.86, blue: 1.00),
            secondaryAccentColor: ThemeColor(red: 0.56, green: 0.22, blue: 1.00),
            backgroundColor: ThemeColor(red: 0.015, green: 0.025, blue: 0.045),
            surfaceColor: ThemeColor(red: 0.04, green: 0.08, blue: 0.11, opacity: 0.92),
            glassOpacity: 0.88,
            glassBlur: 22,
            fontDesign: .rounded
        ),
        AppTheme(
            id: "benz-w211-amber",
            displayName: "Mercedes-Benz W211 · Тёплый янтарь",
            style: .retroDashboard,
            accentColor: ThemeColor(red: 1.00, green: 0.58, blue: 0.18),
            secondaryAccentColor: ThemeColor(red: 1.00, green: 0.88, blue: 0.62),
            backgroundColor: ThemeColor(red: 0.055, green: 0.038, blue: 0.022),
            surfaceColor: ThemeColor(red: 0.13, green: 0.085, blue: 0.045, opacity: 0.96),
            glassOpacity: 0.78,
            glassBlur: 10,
            fontDesign: .monospaced
        ),
        AppTheme(
            id: "bmw-classic-orange",
            displayName: "BMW · Классический оранжевый",
            style: .retroDashboard,
            accentColor: ThemeColor(red: 1.00, green: 0.36, blue: 0.03),
            secondaryAccentColor: ThemeColor(red: 1.00, green: 0.70, blue: 0.20),
            backgroundColor: ThemeColor(red: 0.045, green: 0.025, blue: 0.015),
            surfaceColor: ThemeColor(red: 0.12, green: 0.055, blue: 0.025, opacity: 0.96),
            glassOpacity: 0.74,
            glassBlur: 8,
            fontDesign: .monospaced
        ),
        AppTheme(
            id: "vag-emerald-green",
            displayName: "VAG · Изумрудный",
            style: .retroDashboard,
            accentColor: ThemeColor(red: 0.10, green: 0.92, blue: 0.42),
            secondaryAccentColor: ThemeColor(red: 0.58, green: 1.00, blue: 0.72),
            backgroundColor: ThemeColor(red: 0.015, green: 0.045, blue: 0.026),
            surfaceColor: ThemeColor(red: 0.026, green: 0.11, blue: 0.058, opacity: 0.94),
            glassOpacity: 0.72,
            glassBlur: 8,
            fontDesign: .monospaced
        ),
        AppTheme(
            id: "audi-red-illumination",
            displayName: "Audi · Красная подсветка",
            style: .retroDashboard,
            accentColor: ThemeColor(red: 1.00, green: 0.07, blue: 0.05),
            secondaryAccentColor: ThemeColor(red: 1.00, green: 0.36, blue: 0.24),
            backgroundColor: ThemeColor(red: 0.050, green: 0.012, blue: 0.014),
            surfaceColor: ThemeColor(red: 0.13, green: 0.026, blue: 0.030, opacity: 0.95),
            glassOpacity: 0.72,
            glassBlur: 8,
            fontDesign: .monospaced
        ),
        AppTheme(
            id: "volvo-arctic-white",
            displayName: "Volvo · Арктический лёд",
            style: .minimalist,
            accentColor: ThemeColor(red: 0.86, green: 0.96, blue: 1.00),
            secondaryAccentColor: ThemeColor(red: 0.58, green: 0.76, blue: 0.92),
            backgroundColor: ThemeColor(red: 0.045, green: 0.052, blue: 0.058),
            surfaceColor: ThemeColor(red: 0.15, green: 0.17, blue: 0.18, opacity: 0.92),
            glassOpacity: 0.86,
            glassBlur: 14,
            fontDesign: .default
        )
    ]
}
