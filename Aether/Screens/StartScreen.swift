import SwiftUI

struct StartScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("NEW JAM").mono(13).tracking(3).foregroundStyle(LayerKind.bass.accent)
                Text("Untitled Sketch").ui(26, .semibold).tracking(-0.4)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(store.bpm) BPM · \(store.keyName)").mono(12).tracking(0.5)
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // Layer rows
            VStack(spacing: 12) {
                bassPrompt
                lockedRow(.chords, glyph: "⌁", sub: "Add bass first")
                lockedRow(.drums, glyph: "◷", sub: "Add bass first")
                lockedRow(.lead, glyph: "◇", sub: "The part you jam")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .frame(maxHeight: .infinity)

            // Footer
            Text("Start with the bass — it's the\nfoundation everything sits on.")
                .mono(12)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(Theme.textDim)
                .padding(.bottom, 30)
                .padding(.top, 18)
        }
        .screen()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var bassPrompt: some View {
        Button {
            store.startWithBass()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(LayerKind.bass.tint(0.16))
                    Text("+").font(.system(size: 22, weight: .light)).foregroundStyle(LayerKind.bass.accent)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BASS").ui(16, .semibold).tracking(0.4).foregroundStyle(Theme.textPrimary)
                    Text("Tap to choose a loop").mono(12).foregroundStyle(Color(hex: "7fa3d8"))
                }
                Spacer()
                Text("›").font(.system(size: 20)).foregroundStyle(LayerKind.bass.accent)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(LayerKind.bass.tint(0.09), in: RoundedRectangle(cornerRadius: Theme.rCard))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rCard)
                    .stroke(LayerKind.bass.tint(pulse ? 0.85 : 0.35), lineWidth: 1.5)
            )
            .overlay(alignment: .leading) {
                LayerKind.bass.accent.frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .buttonStyle(.plain)
    }

    private func lockedRow(_ layer: LayerKind, glyph: String, sub: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))
                Text(glyph).font(.system(size: 15)).foregroundStyle(Theme.textDim)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.title).ui(16, .semibold).tracking(0.4).foregroundStyle(Theme.textMuted)
                Text(sub).mono(12).foregroundStyle(Theme.textFaint)
            }
            Spacer()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.05)))
        .overlay(alignment: .leading) {
            layer.tint(0.4).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .opacity(0.5)
    }
}
