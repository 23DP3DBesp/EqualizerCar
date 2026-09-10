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
            return "Modern Glass"
        case .retroDashboard:
            return "Retro Dashboard"
        case .minimalist:
            return "Minimalist"
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
    var background: Color { .white }
    var surface: Color { Color(white: 0.965) }

    var mutedInk: Color {
        Color(white: 0.45)
    }

    var ink: Color {
        Color(white: 0.067)
    }

    var screenBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white, Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var panelTint: Color {
        surface.opacity(glassOpacity)
    }
}

extension AppTheme {
    static let liquidGlassDark = AppTheme(
        id: "liquid-glass-dark",
        displayName: "Studio White",
        style: .minimalist,
        accentColor: ThemeColor(red: 0.86, green: 0.12, blue: 0.18),
        secondaryAccentColor: ThemeColor(red: 0.95, green: 0.85, blue: 0.86),
        backgroundColor: ThemeColor(red: 0.035, green: 0.035, blue: 0.035),
        surfaceColor: ThemeColor(red: 0.10, green: 0.10, blue: 0.10, opacity: 0.94),
        glassOpacity: 0.92,
        glassBlur: 18,
        fontDesign: .default
    )

    static let presets: [AppTheme] = [
        liquidGlassDark,
        AppTheme(
            id: "cyber-cyan",
            displayName: "Cyber Cyan",
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
            displayName: "Mercedes-Benz W211 Warm Amber",
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
            displayName: "BMW Classic Orange",
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
            displayName: "VAG Emerald Green",
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
            displayName: "Audi Red Illumination",
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
            displayName: "Volvo Arctic Ice White",
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
