import SwiftUI

struct ChordsInsideScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let trackID: UUID
    private let layer = LayerKind.chords

    private var track: Track? { store.track(trackID) }
    private var voicings: [[Int]] { track?.chordVoicings ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(layer: layer, title: track?.name ?? layer.title,
                         subtitle: store.chordsSubline(track ?? Track(role: .chords, name: ""))) { dismiss() }
            keyRow
            grid
            columnLabels
            controlRow
            templatesRow
            footer
        }
        .screen()
    }

    // MARK: Key (center of gravity — transposes the whole grid)

    private var keyRow: some View {
        HStack(spacing: 8) {
            Text("KEY").mono(10).tracking(1.5).foregroundStyle(Theme.textDim)
            stepBtn("‹") { store.cycleKeyRoot(-1) }
            Text(store.key.rootName).ui(16, .semibold).foregroundStyle(Theme.textPrimary).frame(minWidth: 30)
            stepBtn("›") { store.cycleKeyRoot(1) }
            Spacer()
            Button { store.toggleMode() } label: {
                Text(store.key.mode.label).mono(11, .semibold).tracking(1).foregroundStyle(layer.accent)
                    .padding(.vertical, 7).padding(.horizontal, 14)
                    .background(layer.tint(0.14), in: Capsule())
                    .overlay(Capsule().stroke(layer.tint(0.4)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.top, 2).padding(.bottom, 8)
    }

    private func stepBtn(_ s: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s).font(.system(size: 18)).foregroundStyle(Theme.textMuted)
                .frame(width: 32, height: 32)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.hairline(0.08)))
        }
        .buttonStyle(.plain)
    }

    // MARK: The voice-lane grid

    private var grid: some View {
        Group {
            if voicings.isEmpty {
                VStack(spacing: 10) {
                    Text("No progression yet").ui(15, .semibold).foregroundStyle(Theme.textSecondary)
                    Text("Pick a vibe below, or ＋ Chord — then drag the notes to shape the flow.")
                        .mono(11).foregroundStyle(Theme.textFaint).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 30)
            } else {
                ChordLaneGrid(trackID: trackID, accent: layer.accent)
            }
        }
        .padding(.horizontal, 14).padding(.top, 4)
        .frame(maxHeight: .infinity)
    }

    // Chord names + per-chord duration + remove, aligned under each column.
    private var columnLabels: some View {
        HStack(spacing: 0) {
            ForEach(voicings.indices, id: \.self) { c in
                VStack(spacing: 1) {
                    HStack(spacing: 5) {
                        Text(store.voicingName(voicings[c])).mono(11, .semibold)
                            .foregroundStyle(layer.accent).lineLimit(1).minimumScaleFactor(0.6)
                        if voicings.count > 1 {
                            Button { store.removeChord(trackID, at: c) } label: {
                                Text("×").font(.system(size: 12)).foregroundStyle(Theme.textFaint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // FIT/FREE made visible — each chord's share of the loop.
                    Text(durationLabel).mono(8).foregroundStyle(Theme.textFaint)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14).padding(.top, 6)
        .opacity(voicings.isEmpty ? 0 : 1)
    }

    private var durationLabel: String {
        let n = max(voicings.count, 1)
        let bars: Double = track?.timing == .free ? 1.0 : 4.0 / Double(n)
        if bars >= 1, bars.rounded() == bars { return "\(Int(bars)) bar\(Int(bars) == 1 ? "" : "s")" }
        if bars == 0.5 { return "½ bar" }
        return String(format: "%.1f bars", bars)
    }
    private var loopInfo: String {
        let n = max(voicings.count, 1)
        let total = track?.timing == .free ? n : 4
        return "\(total)-bar loop"
    }

    // MARK: Controls

    private var controlRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(ChordTiming.allCases, id: \.self) { mode in
                    let on = track?.timing == mode
                    Text(mode.label).mono(10, .semibold).tracking(1)
                        .lineLimit(1).fixedSize()
                        .foregroundStyle(on ? Color(hex: "1a1206") : Theme.textDim)
                        .padding(.vertical, 6).padding(.horizontal, 11)
                        .background(on ? layer.accent : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                        .onTapGesture { store.setChordTiming(trackID, mode) }
                }
            }
            .padding(3).background(Theme.panel, in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline(0.08)))
            .fixedSize()

            if !voicings.isEmpty {
                Text(loopInfo).mono(8).foregroundStyle(Theme.textFaint).fixedSize()
            }

            Spacer()

            if !voicings.isEmpty {
                pill("✦ SMOOTH", filled: true) { store.autoSmooth(trackID) }
            }
            pill("＋ CHORD") { store.addChord(trackID) }
            if !voicings.isEmpty { pill("✕") { store.clearChords(trackID) } }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func pill(_ label: String, filled: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).mono(10, .semibold).tracking(0.5)
                .lineLimit(1).fixedSize()
                .foregroundStyle(filled ? layer.accent : Theme.textMuted)
                .padding(.vertical, 7).padding(.horizontal, 11)
                .background(filled ? layer.tint(0.14) : Theme.panel, in: Capsule())
                .overlay(Capsule().stroke(filled ? layer.tint(0.4) : Theme.hairline(0.1)))
        }
        .buttonStyle(.plain)
    }

    private var templatesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.chordTemplates) { tmpl in
                    VStack(spacing: 2) {
                        Text(tmpl.name).ui(13, .semibold).foregroundStyle(Theme.textSecondary)
                        Text(tmpl.mood).mono(8).tracking(0.5).foregroundStyle(Theme.textFaint)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 14)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.hairline(0.07)))
                    .contentShape(Rectangle())
                    .onTapGesture { store.applyChordTemplate(trackID, tmpl) }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            ArcKnob(value: store.eqValue(trackID), accent: layer.accent, size: 50, lineWidth: 5,
                    trackColor: layer.tint(0.16), travel: 180,
                    onChange: { store.setEQ(trackID, $0) }) {
                VStack(spacing: 0) {
                    Text(Curves.hzLabel(store.eqValue(trackID))).mono(10).foregroundStyle(Theme.textPrimary)
                    Text("CUT").mono(7).tracking(1).foregroundStyle(Theme.textDim)
                }
            }
            Button { store.beginEditing(trackID); store.path.append(.synthEditor(trackID)) } label: {
                Text("⚙ EDIT SOUND").mono(12, .semibold).tracking(1).foregroundStyle(Color(hex: "b79ce0"))
                    .frame(maxWidth: .infinity).padding(12)
                    .background(layer.tint(0.10), in: RoundedRectangle(cornerRadius: Theme.rPad))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rPad).stroke(layer.tint(0.4)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 18)
    }
}

// MARK: - The draggable voice-lane grid

private struct ChordLaneGrid: View {
    @EnvironmentObject var store: AppStore
    let trackID: UUID
    let accent: Color

    // Live drag: which chord/note, and where it's hovering — committed on release.
    @State private var dragChord: Int? = nil
    @State private var dragFrom: Int? = nil
    @State private var dragCur: Int? = nil

    private var voicings: [[Int]] { store.track(trackID)?.chordVoicings ?? [] }
    private var rows: [Int] { Array(store.chordRows) }

    var body: some View {
        GeometryReader { geo in
            let cols = max(voicings.count, 1)
            let colW = geo.size.width / CGFloat(cols)
            let rowH = geo.size.height / CGFloat(rows.count)
            let maxIdx = rows.last ?? 12

            // effective (possibly mid-drag) index of a note, and pixel positions
            let eff: (Int, Int) -> Int = { c, idx in
                (dragChord == c && dragFrom == idx) ? (dragCur ?? idx) : idx
            }
            let x: (Int) -> CGFloat = { c in colW * (CGFloat(c) + 0.5) }
            let y: (Int) -> CGFloat = { idx in rowH * (CGFloat(maxIdx - idx) + 0.5) }

            ZStack(alignment: .topLeading) {
                // faint octave guide lines (every tonic row)
                ForEach(rows.filter { (($0 % 7) + 7) % 7 == 0 }, id: \.self) { idx in
                    Rectangle().fill(accent.opacity(0.08)).frame(height: 1)
                        .position(x: geo.size.width / 2, y: y(idx))
                }

                // voice-leading lines (connect chords by pitch rank)
                Path { p in
                    guard voicings.count > 1 else { return }
                    for c in 0..<(voicings.count - 1) {
                        let a = voicings[c].map { eff(c, $0) }.sorted()
                        let b = voicings[c + 1].map { eff(c + 1, $0) }.sorted()
                        for k in 0..<min(a.count, b.count) {
                            p.move(to: CGPoint(x: x(c), y: y(a[k])))
                            p.addLine(to: CGPoint(x: x(c + 1), y: y(b[k])))
                        }
                    }
                }
                .stroke(accent.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // per-column tap surface to ADD a note
                ForEach(voicings.indices, id: \.self) { c in
                    Rectangle().fill(Color.white.opacity(0.001))
                        .frame(width: colW, height: geo.size.height)
                        .position(x: x(c), y: geo.size.height / 2)
                        .gesture(SpatialTapGesture().onEnded { val in
                            let idx = maxIdx - Int(val.location.y / rowH)
                            store.addNote(trackID, chord: c, idx)
                        })
                }

                // the note dots
                ForEach(voicings.indices, id: \.self) { c in
                    ForEach(voicings[c], id: \.self) { idx in
                        dot(label: store.noteLetter(idx),
                            active: dragChord == c && dragFrom == idx)
                            .position(x: x(c), y: y(eff(c, idx)))
                            .gesture(
                                DragGesture(minimumDistance: 6)
                                    .onChanged { g in
                                        dragChord = c; dragFrom = idx
                                        let d = Int((-g.translation.height / rowH).rounded())
                                        dragCur = min(rows.last!, max(rows.first!, idx + d))
                                    }
                                    .onEnded { _ in
                                        if let cur = dragCur, cur != idx {
                                            store.moveNote(trackID, chord: c, from: idx, to: cur)
                                        }
                                        dragChord = nil; dragFrom = nil; dragCur = nil
                                    }
                            )
                            .onTapGesture { store.removeNote(trackID, chord: c, value: idx) }
                    }
                }
            }
        }
        .background(Theme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.06)))
    }

    private func dot(label: String, active: Bool) -> some View {
        Text(label).mono(10, .semibold)
            .foregroundStyle(active ? Color(hex: "1a1206") : Color(hex: "1a1206"))
            .frame(width: 26, height: 26)
            .background(active ? Color.white : accent, in: Circle())
            .overlay(Circle().stroke(active ? accent : accent.opacity(0.5), lineWidth: active ? 2 : 1))
            .shadow(color: accent.opacity(active ? 0.7 : 0.35), radius: active ? 8 : 3)
    }
}
