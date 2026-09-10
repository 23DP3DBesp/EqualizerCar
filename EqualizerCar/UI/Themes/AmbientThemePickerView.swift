import SwiftUI

struct AmbientThemePickerView: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var customAccent = Color.orange

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ambient Sync & Theme", systemImage: "lightbulb.led.fill")
                .font(.headline)
                .foregroundStyle(themeManager.current.ink)

            livePreview

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                ForEach(themeManager.availableThemes) { theme in
                    themeTile(theme)
                }
            }

            customControls
        }
        .padding(14)
        .themedPanel(cornerRadius: 12)
        .onAppear {
            customAccent = themeManager.customTheme.accent
        }
    }

    private var livePreview: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(themeManager.current.displayName)
                    .font(.system(.subheadline, design: themeManager.current.fontDesign.swiftUIFontDesign, weight: .bold))
                    .foregroundStyle(themeManager.current.ink)
                    .lineLimit(2)
                Text(themeManager.current.style.displayName)
                    .font(.caption.monospaced())
                    .foregroundStyle(themeManager.current.mutedInk)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index.isMultiple(of: 2) ? themeManager.current.accent : themeManager.current.secondaryAccent)
                        .frame(width: 8, height: CGFloat(16 + index * 6))
                        .themedGlow(radius: 7)
                }
            }

            Image(systemName: "play.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Circle().fill(themeManager.current.accent))
        }
        .padding(12)
        .background(themeManager.current.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(themeManager.current.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func themeTile(_ theme: AppTheme) -> some View {
        Button {
            themeManager.selectTheme(theme)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(theme.accent).frame(width: 18, height: 18)
                    Circle().fill(theme.secondaryAccent).frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.surface)
                        .frame(width: 30, height: 18)
                    Spacer()
                    if theme.id == themeManager.current.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    }
                }

                Text(theme.displayName)
                    .font(.system(.caption, design: theme.fontDesign.swiftUIFontDesign, weight: .bold))
                    .foregroundStyle(themeManager.current.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(theme.style.displayName)
                    .font(.caption2.monospaced())
                    .foregroundStyle(themeManager.current.mutedInk)
            }
            .padding(10)
            .frame(minHeight: 104, alignment: .topLeading)
            .background(theme.surface.opacity(theme.id == themeManager.current.id ? 0.92 : 0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.id == themeManager.current.id ? theme.accent.opacity(0.75) : Color.black.opacity(0.04), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var customControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(themeManager.current.accent.opacity(0.25))

            ColorPicker("Custom Ambient Color", selection: Binding(
                get: { customAccent },
                set: { color in
                    customAccent = color
                    themeManager.updateCustomAccent(color)
                }
            ), supportsOpacity: false)
            .foregroundStyle(themeManager.current.ink)

            Picker("Custom Layout", selection: Binding(
                get: { themeManager.customTheme.style },
                set: { themeManager.updateCustomStyle($0) }
            )) {
                ForEach(AppThemeStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Opacity \(Int(themeManager.customTheme.glassOpacity * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.mutedInk)
                Slider(value: Binding(
                    get: { themeManager.customTheme.glassOpacity },
                    set: { themeManager.updateCustomGlass(opacity: $0, blur: themeManager.customTheme.glassBlur) }
                ), in: 0.35...1)

                Text("Glass Blur \(Int(themeManager.customTheme.glassBlur))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.current.mutedInk)
                Slider(value: Binding(
                    get: { themeManager.customTheme.glassBlur },
                    set: { themeManager.updateCustomGlass(opacity: themeManager.customTheme.glassOpacity, blur: $0) }
                ), in: 0...32)
            }
        }
    }
}

#Preview {
    AmbientThemePickerView(themeManager: ThemeManager())
        .carAmbientTheme(ThemeManager())
        .preferredColorScheme(.light)
        .padding()
        .background(AppTheme.liquidGlassDark.screenBackground)
}
