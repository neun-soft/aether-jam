import SwiftUI

struct SynthEditorScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let trackID: UUID

    private var accent: Color { store.editingRole.accent }

    var body: some View {
        VStack(spacing: 0) {
            header
            layerTabs
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    macrosPanel
                    soundDesignRow
                    if store.synthAdvanced { advancedPanels }
                }
                .padding(.horizontal, 16)
            }
            saveButton
            Color.clear.frame(height: 22)
        }
        .screen()
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 11) {
                BackButton { dismiss() }
                Button { store.path.append(.mySounds) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.presetName).ui(17, .semibold).tracking(0.3).foregroundStyle(accent)
                        Text("SAME ENGINE · EDITING \(store.track(trackID)?.name ?? store.editingRole.title)").mono(11)
                            .foregroundStyle(Theme.textDim)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { store.path.append(.mySounds) } label: {
                Text("LIBRARY").mono(11, .semibold).tracking(0.5).foregroundStyle(Theme.textMuted)
                    .padding(.vertical, 6).padding(.horizontal, 11)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
    }

    // MARK: Layer tabs

    private var layerTabs: some View {
        // One tab per sound-bearing track (drums use the sample synth, no wavetable editor).
        let editable = store.tracks.filter { $0.role != .drums }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(editable) { t in
                    let on = store.editingTrackID == t.id
                    Text(t.name).mono(11, .semibold).tracking(0.5)
                        .foregroundStyle(on ? t.role.accent : Theme.textDim)
                        .fixedSize()
                        .padding(.vertical, 8).padding(.horizontal, 14)
                        .background(on ? t.role.tint(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.rSmall))
                        .overlay(RoundedRectangle(cornerRadius: Theme.rSmall).stroke(on ? t.role.accent : Color.clear))
                        .contentShape(Rectangle())
                        .onTapGesture { store.beginEditing(t.id) }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 2).padding(.bottom, 10)
    }

    // MARK: Macros

    private var macrosPanel: some View {
        let macros: [(String, String)] = [("bright", "BRIGHT"), ("move", "MOVEMENT"), ("space", "SPACE"), ("drive", "DRIVE")]
        return VStack(alignment: .leading, spacing: 0) {
            Text("MACROS · QUICK SHAPE").mono(11).tracking(2).foregroundStyle(Theme.textDim)
                .padding(.bottom, 14)
            HStack(alignment: .top) {
                ForEach(macros, id: \.0) { key, label in
                    VStack(spacing: 6) {
                        SynthKnob(key: key, size: 70, lineWidth: 6, accent: accent,
                                  trackColor: Color.white.opacity(0.07)) {
                            Text("\(Int((store.synth[key]) * 100))").mono(13).foregroundStyle(Theme.textPrimary)
                        }
                        Text(label).mono(9).tracking(0.5).foregroundStyle(Theme.neutral)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.06)))
    }

    // MARK: Sound design toggle row

    private var soundDesignRow: some View {
        HStack {
            Text("SOUND DESIGN").mono(11).tracking(2).foregroundStyle(Theme.textDim)
            Spacer()
            let on = store.synthAdvanced
            Text("ADVANCED").mono(11, .semibold).tracking(0.5)
                .foregroundStyle(on ? accent : Theme.neutral)
                .padding(.vertical, 7).padding(.horizontal, 13)
                .background(on ? accent.opacity(0.16) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? accent : Theme.hairline(0.08)))
                .contentShape(Rectangle())
                .onTapGesture { store.toggleAdvanced() }
        }
        .padding(.vertical, 12).padding(.horizontal, 2)
        .padding(.top, 2)
    }

    // MARK: Advanced panels

    private var advancedPanels: some View {
        VStack(spacing: 12) {
            oscillatorCard
            HStack(spacing: 12) { filterCard; envelopeCard }
            shimmerCard
        }
        .padding(.bottom, 14)
    }

    private var oscillatorCard: some View {
        let voices = Int((1 + store.synth.oUni * 8).rounded())
        let detune = Int((store.synth.oUni * 40).rounded())
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("OSCILLATOR · WAVETABLE").mono(10).tracking(1.5).foregroundStyle(Theme.textDim)
                Spacer()
                Text("\(voices) VOICES · \(detune)c").mono(10).foregroundStyle(Theme.textMuted)
            }
            .padding(.bottom, 6)
            GeometryReader { geo in
                Curves.osc(morph: store.synth.oWave, rect: geo.size)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .shadow(color: Color.white.opacity(0.2), radius: 2)
            }
            .frame(height: 54)
            HStack(spacing: 20) {
                miniKnob("oWave", "WT POS", accent: accent, track: Color.white.opacity(0.07))
                miniKnob("oUni", "UNISON", accent: accent, track: Color.white.opacity(0.07))
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 13).padding(.horizontal, 15)
        .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.06)))
    }

    private var filterCard: some View {
        let green = LayerKind.drums.accent
        return VStack(alignment: .leading, spacing: 0) {
            Text("FILTER").mono(10).tracking(1.5).foregroundStyle(Theme.textDim).padding(.bottom, 6)
            GeometryReader { geo in
                Curves.eqCurve(cut: store.synth.fCut, rect: geo.size, srcW: 320, srcH: 70)
                    .stroke(green, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    .shadow(color: green.opacity(0.45), radius: 4)
            }
            .frame(height: 54)
            HStack(spacing: 14) {
                miniKnob("fCut", "CUT", size: 40, accent: green, track: green.opacity(0.14))
                miniKnob("fRes", "RES", size: 40, accent: green, track: green.opacity(0.14))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13).padding(.horizontal, 14)
        .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.06)))
    }

    private var envelopeCard: some View {
        let amber = LayerKind.lead.accent
        return VStack(alignment: .leading, spacing: 0) {
            Text("ENVELOPE").mono(10).tracking(1.5).foregroundStyle(Theme.textDim).padding(.bottom, 6)
            GeometryReader { geo in
                let adsr = Curves.adsr(a: store.synth.eA, d: store.synth.eD, s: store.synth.eS, r: store.synth.eR, rect: geo.size)
                ZStack {
                    adsr.fill.fill(amber.opacity(0.14))
                    adsr.stroke.stroke(amber, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                        .shadow(color: amber.opacity(0.45), radius: 4)
                }
            }
            .frame(height: 54)
            HStack(spacing: 5) {
                ForEach([("eA", "A"), ("eH", "H"), ("eD", "D"), ("eS", "S"), ("eR", "R")], id: \.0) { key, lbl in
                    miniKnob(key, lbl, size: 32, accent: amber, track: amber.opacity(0.14))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13).padding(.horizontal, 14)
        .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.06)))
    }

    private var shimmerCard: some View {
        let lav = LayerKind.chords.accent
        let sendOn = store.editingTrackID.map { store.isShimmerOn($0) } ?? false
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("✦ SHIMMER REVERB").mono(10).tracking(1.5).foregroundStyle(lav)
                Spacer()
                // Per-instrument send: does THIS instrument dip into the shimmer river?
                Text(sendOn ? "SEND ON" : "SEND OFF").mono(9, .semibold).tracking(0.5)
                    .foregroundStyle(sendOn ? Color(hex: "1a1206") : Theme.textDim)
                    .padding(.vertical, 5).padding(.horizontal, 11)
                    .background(sendOn ? lav : Color.white.opacity(0.05), in: Capsule())
                    .overlay(Capsule().stroke(sendOn ? lav : Theme.hairline(0.1)))
                    .contentShape(Capsule())
                    .onTapGesture { if let id = store.editingTrackID { store.toggleShimmer(id) } }
            }
            .padding(.bottom, 12)
            HStack {
                ForEach([("fxSize", "SIZE"), ("fxShim", "SHIMMER"), ("fxMix", "MIX")], id: \.0) { key, lbl in
                    VStack(spacing: 5) {
                        SynthKnob(key: key, size: 46, lineWidth: 7, accent: lav, trackColor: lav.opacity(0.16)) { EmptyView() }
                        Text(lbl).mono(9).foregroundStyle(Color(hex: "9b8fc0"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 13).padding(.horizontal, 16)
        .background(
            LinearGradient(colors: [lav.opacity(0.12), Color(hex: "54e6ff").opacity(0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.rCard)
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(lav.opacity(0.22)))
    }

    private func miniKnob(_ key: String, _ label: String, size: CGFloat = 42, accent: Color, track: Color) -> some View {
        VStack(spacing: size <= 32 ? 3 : 4) {
            SynthKnob(key: key, size: size, lineWidth: size <= 32 ? 8 : 7, accent: accent, trackColor: track) { EmptyView() }
            Text(label).mono(9).foregroundStyle(Theme.textDim)
        }
    }

    // MARK: Save

    private var saveButton: some View {
        let saved = store.justSaved
        return Text(saved ? "✓ SAVED TO MY SOUNDS" : "SAVE TO MY SOUNDS")
            .mono(13, .semibold).tracking(1)
            .foregroundStyle(saved ? accent : Color(hex: "0c0e14"))
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(saved ? accent.opacity(0.16) : accent, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(accent))
            .padding(.horizontal, 18).padding(.top, 14)
            .contentShape(Rectangle())
            .onTapGesture { store.saveSound() }
    }
}

// MARK: - Synth knob bound to store params

struct SynthKnob<Center: View>: View {
    @EnvironmentObject var store: AppStore
    let key: String
    var size: CGFloat = 70
    var lineWidth: CGFloat = 6
    var accent: Color
    var trackColor: Color
    @ViewBuilder var center: () -> Center

    var body: some View {
        ArcKnob(value: store.synth[key], accent: accent, size: size, lineWidth: lineWidth,
                trackColor: trackColor, travel: 170,
                onChange: { store.setSynth(key, $0) }, center: center)
    }
}
