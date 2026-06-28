import SwiftUI

struct MySoundsScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    var addMode: Bool = false

    private var accent: Color { store.editingRole.accent }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !addMode { saveBanner }
            Text(addMode ? "TAP A SOUND TO ADD IT AS A TRACK" : "SAVED · \(store.editingRole.title) ⌄")
                .mono(11).tracking(1.5)
                .foregroundStyle(Theme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(store.presets.enumerated()), id: \.element.id) { idx, preset in
                        libraryRow(idx, preset)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 18)
            }
        }
        .screen()
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackButton { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text(addMode ? "Add Instrument" : "My Sounds").ui(20, .semibold).tracking(-0.2).foregroundStyle(Theme.textPrimary)
                Text(addMode ? "PICK A SOUND · ADDS A NEW TRACK" : "GLOBAL LIBRARY · REUSE ON ANY LAYER")
                    .mono(11).foregroundStyle(Theme.textDim)
            }
            Spacer()
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var saveBanner: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LayerKind.lead.tint(0.16))
                Text("+").font(.system(size: 22, weight: .light)).foregroundStyle(accent)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Save current sound").ui(15, .semibold).foregroundStyle(Theme.textPrimary)
                Text("\(store.presetName) · from \(store.editingRole.title)").mono(11)
                    .foregroundStyle(Color(hex: "9b8a6a"))
            }
            Spacer()
            Text("SAVE").mono(11, .semibold).tracking(1).foregroundStyle(accent)
        }
        .padding(.vertical, 15).padding(.horizontal, 16)
        .background(LayerKind.lead.tint(0.08), in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(LayerKind.lead.tint(0.4)))
        .overlay(alignment: .leading) {
            accent.frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, 18).padding(.top, 14)
        .contentShape(Rectangle())
        .onTapGesture { store.saveSound() }
    }

    private func libraryRow(_ idx: Int, _ preset: Preset) -> some View {
        let sel = store.activePreset == idx
        let col = preset.col
        return HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11).fill(col.tint(0.18))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(col.accent))
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name).ui(15, .semibold)
                    .foregroundStyle(sel ? .white : Theme.textPrimary)
                Text(preset.desc).mono(11).foregroundStyle(Theme.textDim)
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 6)
            if addMode {
                Text("＋").font(.system(size: 18)).foregroundStyle(col.accent)
                    .frame(width: 30, height: 30)
                    .background(col.tint(0.14), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text(preset.tag).mono(10).tracking(1).foregroundStyle(col.accent)
                    .padding(.vertical, 4).padding(.horizontal, 9)
                    .background(col.tint(0.14), in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 15)
        .background(sel && !addMode ? col.tint(0.10) : Theme.panel, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(sel && !addMode ? col.accent : Theme.hairline(0.06)))
        .contentShape(Rectangle())
        .onTapGesture { if addMode { store.addTrackFromSound(preset) } else { store.selectPreset(idx) } }
        .contextMenu {
            Button { store.duplicatePreset(idx) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            if preset.params != nil {
                Button(role: .destructive) { store.deletePreset(idx) } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}
