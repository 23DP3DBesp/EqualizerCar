import SwiftUI

struct PresetsPanelView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @ObservedObject var presetManager: PresetManager
    @Binding var showSavePresetAlert: Bool
    let importAction: () -> Void
    let exportAction: () -> Void

    @State private var selectedCategory: PresetCategory = .all
    @State private var favoritesOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Picker("Category", selection: $selectedCategory) {
                    ForEach(PresetCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)

                Toggle(isOn: $favoritesOnly) {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .toggleStyle(.button)

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
        .navigationTitle("Presets")
    }

    private var header: some View {
        HStack {
            Text("Profiles")
                .font(.headline)
            Spacer()
            Button(action: importAction) {
                Image(systemName: "square.and.arrow.down")
            }
            Button(action: exportAction) {
                Image(systemName: "square.and.arrow.up")
            }
            Button {
                showSavePresetAlert = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        HStack(spacing: 12) {
            Button {
                presetManager.apply(preset, to: audioManager)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.body.weight(.semibold))
                    Text("\(preset.category.rawValue) - \(preset.isBuiltIn ? "Built-in" : "User preset")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if presetManager.activePresetID == preset.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                }
            }
            .buttonStyle(.plain)

            Button {
                presetManager.toggleFavorite(preset)
            } label: {
                Image(systemName: preset.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(preset.isFavorite ? .pink : .secondary)
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
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var visiblePresets: [Preset] {
        presetManager.presets(in: selectedCategory, favoritesOnly: favoritesOnly)
    }
}
