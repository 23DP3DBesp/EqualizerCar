import SwiftUI

enum LiquidGlassTheme {
    static let accent = Color(red: 0.86, green: 0.12, blue: 0.18)
    static let accentSoft = accent.opacity(0.10)
    static let amber = Color.orange
    static let ink = Color(white: 0.067)
    static let mutedInk = Color(white: 0.45)
    static let panel = Color.white
    static let panelRaised = Color(white: 0.965)
    static let hairline = Color.black.opacity(0.07)
    static let shadow = Color.black.opacity(0.04)
    static var screenBackground: LinearGradient {
        LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func liquidGlassPanel(cornerRadius: CGFloat = 8, tint: Color = .white, interactive: Bool = false) -> some View {
        self.background(Color(white: 0.975))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    func musicHover() -> some View { modifier(MusicHoverModifier()) }
}

private struct MusicHoverModifier: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? Color(white: 0.96) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
            .animation(.easeInOut(duration: 0.18), value: hovering)
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
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: open) {
                    Group {
                        if artworkTrack?.artworkData != nil {
                            TrackArtwork(track: artworkTrack, size: 140)
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.96))
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
                        .foregroundStyle(.white).frame(width: 38, height: 38)
                        .background(theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play \(title)")
                .padding(8)
                .opacity(hovering || sizeClass == .compact ? 1 : 0)
            }
            Button(action: open) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(theme.mutedInk).lineLimit(1)
                }
            }.buttonStyle(.plain)
        }
        .frame(width: 140, alignment: .leading)
        .padding(6)
        .offset(y: hovering ? -2 : 0)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: hovering)
    }
}
