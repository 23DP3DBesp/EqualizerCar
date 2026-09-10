import SwiftUI

struct PresetsPanelView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var presetManager: PresetManager
    @Binding var showSavePresetAlert: Bool
    @Environment(\.carAmbientTheme) private var theme
    let importAction: () -> Void
    let exportAction: () -> Void

    @State private var selectedCategory: PresetCategory = .all
    @State private var favoritesOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                filterDeck

                if visiblePresets.isEmpty {
                    ContentUnavailableView("No Presets", systemImage: "square.grid.2x2")
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visiblePresets) { preset in
                            presetRow(preset)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(theme.screenBackground.ignoresSafeArea())
        .navigationTitle("Presets")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PROFILE BANK")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text("\(visiblePresets.count) visible presets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.mutedInk)
            }

            Spacer()

            Button(action: importAction) {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)

            Button(action: exportAction) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)

            Button {
                showSavePresetAlert = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .liquidGlassPanel(cornerRadius: 14, tint: theme.surface.opacity(0.96))
    }

    private var filterDeck: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(PresetCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Label(category.rawValue, systemImage: category.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedCategory.systemImage)
                        .foregroundStyle(theme.secondaryAccent)
                    Text(selectedCategory.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.mutedInk)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(theme.surface.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.accent.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Toggle(isOn: $favoritesOnly) {
                Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                    .frame(width: 40, height: 40)
            }
            .toggleStyle(.button)
            .tint(.pink)
        }
        .padding(12)
        .liquidGlassPanel(cornerRadius: 12, tint: theme.surface.opacity(theme.glassOpacity))
    }

    private func presetRow(_ preset: Preset) -> some View {
        HStack(spacing: 12) {
            Button {
                presetManager.apply(preset, to: audioManager)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: preset.category.systemImage)
                        .foregroundStyle(presetManager.activePresetID == preset.id ? theme.secondaryAccent : theme.mutedInk)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Text("\(preset.category.rawValue) - \(preset.isBuiltIn ? "Built-in" : "User preset")")
                            .font(.caption)
                            .foregroundStyle(theme.mutedInk)
                    }

                    Spacer()

                    if presetManager.activePresetID == preset.id {
                        Text("LOADED")
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(theme.secondaryAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.secondaryAccent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                presetManager.toggleFavorite(preset)
            } label: {
                Image(systemName: preset.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(preset.isFavorite ? .pink : theme.mutedInk)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    presetManager.duplicatePreset(preset)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                if !preset.isBuiltIn {
                    Button(role: .destructive) {
                        presetManager.deletePreset(preset)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(theme.mutedInk)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(14)
        .background(presetManager.activePresetID == preset.id ? theme.secondaryAccent.opacity(0.14) : theme.surface.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(presetManager.activePresetID == preset.id ? theme.secondaryAccent.opacity(0.36) : theme.accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var visiblePresets: [Preset] {
        presetManager.presets(in: selectedCategory, favoritesOnly: favoritesOnly)
    }
}
