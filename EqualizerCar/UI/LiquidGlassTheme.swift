import SwiftUI

enum LiquidGlassTheme {
    static let accent = Color(red: 0.86, green: 0.12, blue: 0.18)
    static let accentSoft = accent.opacity(0.10)
    static let amber = Color.orange
    static let ink = Color.primary
    static let mutedInk = Color.secondary
    static let panel = Color(uiColor: .systemBackground)
    static let panelRaised = Color(uiColor: .secondarySystemBackground)
    static let hairline = Color.primary.opacity(0.08)
    static let shadow = Color.black.opacity(0.04)
    static var screenBackground: LinearGradient {
        LinearGradient(colors: [panel, panel], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func liquidGlassPanel(cornerRadius: CGFloat = 8, tint: Color = .white, interactive: Bool = false) -> some View {
        modifier(AdaptivePanelModifier(cornerRadius: cornerRadius))
    }

    func musicHover() -> some View { modifier(MusicHoverModifier()) }
}

private struct MusicHoverModifier: ViewModifier {
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? theme.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hovering)
            .hoverEffect(.highlight)
    }
}

struct MusicCollectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var artworkTrack: Track? = nil
    let open: () -> Void
    let play: () -> Void
    @Environment(\.carAmbientTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: open) {
                    Group {
                        if artworkTrack?.artworkData != nil {
                            TrackArtwork(track: artworkTrack, size: 140)
                        } else {
                            RoundedRectangle(cornerRadius: 24).fill(theme.surface)
                        .overlay {
                            Image(systemName: icon).font(.system(size: 32, weight: .light))
                                .foregroundStyle(icon == "heart.fill" ? theme.accent : theme.ink)
                        }
                        .frame(width: 140, height: 140)
                        }
                    }
                }
                .buttonStyle(.plain)
                Button(action: play) {
                    Image(systemName: "play.fill").font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.onAccent).frame(width: 44, height: 44)
                        .background(theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Воспроизвести \(title)"))
                .padding(8)
                .opacity(hovering || sizeClass == .compact ? 1 : 0)
            }
            Button(action: open) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(1)
                }
            }.buttonStyle(.plain)
        }
        .frame(width: 140, alignment: .leading)
        .padding(6)
        .offset(y: hovering && !reduceMotion ? -2 : 0)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: hovering)
    }
}

private struct AdaptivePanelModifier: ViewModifier {
    @Environment(\.carAmbientTheme) private var theme
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content.background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: max(cornerRadius, 20), style: .continuous))
    }
}
