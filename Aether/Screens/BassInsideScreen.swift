import SwiftUI

struct BassInsideScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let trackID: UUID
    private let layer = LayerKind.bass

    // Drag-to-reorder state for the note-line strip.
    @State private var dragIndex: Int? = nil
    @State private var dragDX: CGFloat = 0

    private var track: Track? { store.track(trackID) }
    private var notes: [Int] { track?.bassNotes ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(layer: layer, title: track?.name ?? layer.title,
                         subtitle: store.loopName(track ?? Track(role: .bass, name: ""))) { dismiss() }

            bassLineCard
            sequenceStrip
            controlRow

            SectionLabel("GROOVE LOOP").padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 6)
            LoopSwatchStrip(loops: store.bassLoops, selected: track?.loopIdx, layer: layer) {
                store.selectLoop(trackID, $0)
            }

            Spacer(minLength: 0)
            pitchRow
            VolumeRow(layer: layer, value: store.volumeOf(trackID)) { store.setVolume(trackID, $0) }
                .padding(.horizontal, 18).padding(.top, 10)
            footer
        }
        .screen()
    }

    // MARK: Bass line — the scale row you tap to build the line

    private var bassLineCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("BASS LINE").mono(11).tracking(2).foregroundStyle(Color(hex: "7fa3d8"))
                Spacer()
                Button { store.autofillBassFromChords(trackID) } label: {
                    Text("⤵ FROM CHORDS").mono(9, .semibold).tracking(0.5).foregroundStyle(layer.accent)
                        .padding(.vertical, 6).padding(.horizontal, 11)
                        .background(layer.tint(0.14), in: Capsule())
                        .overlay(Capsule().stroke(layer.tint(0.4)))
                }
                .buttonStyle(.plain)
            }
            // One octave of the key's scale + the octave tonic. Tap to append.
            HStack(spacing: 5) {
                ForEach(0..<8, id: \.self) { deg in
                    Button { store.addBassNote(trackID, deg) } label: {
                        VStack(spacing: 1) {
                            Text(store.bassNoteName(deg)).ui(15, .semibold).foregroundStyle(Theme.textPrimary)
                            Text(deg == 0 ? "ROOT" : (deg == 7 ? "8VE" : "\(deg + 1)"))
                                .mono(7).foregroundStyle(deg == 0 ? layer.tint(0.9) : Theme.textFaint)
                        }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background((deg == 0 || deg == 7) ? layer.tint(0.12) : Theme.panel,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke((deg == 0 || deg == 7) ? layer.tint(0.4) : Theme.hairline(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 13).padding(.horizontal, 16)
        .background(layer.tint(0.07), in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(layer.tint(0.2)))
        .padding(.horizontal, 18).padding(.top, 6)
    }

    // MARK: Sequence strip (ordered, reorderable, removable)

    private let slot: CGFloat = 70

    private var sequenceStrip: some View {
        Group {
            if notes.isEmpty {
                Text("No notes — the loop holds the key root. Tap notes above to build a line.")
                    .mono(11).foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 58).padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(notes.enumerated()), id: \.offset) { i, deg in
                            seqPill(i, deg)
                        }
                    }
                    .padding(.horizontal, 18).frame(minHeight: 58)
                }
            }
        }
        .padding(.top, 8)
    }

    private func seqPill(_ i: Int, _ deg: Int) -> some View {
        let dragging = dragIndex == i
        return VStack(spacing: 2) {
            Text(store.bassNoteName(deg)).ui(15, .semibold).foregroundStyle(Theme.textPrimary)
            Text(durationLabel).mono(8).foregroundStyle(layer.tint(0.9))
        }
        .frame(width: 60, height: 48)
        .background(layer.tint(dragging ? 0.28 : 0.12), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(layer.tint(dragging ? 0.8 : 0.35)))
        .overlay(alignment: .topTrailing) {
            Button { store.removeBassNote(trackID, at: i) } label: {
                Text("×").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                    .frame(width: 17, height: 17)
                    .background(Theme.panel, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline(0.12)))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
        .offset(x: dragging ? dragDX : 0)
        .zIndex(dragging ? 1 : 0)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { g in dragIndex = i; dragDX = g.translation.width }
                .onEnded { g in
                    let shift = Int((g.translation.width / slot).rounded())
                    if shift != 0 { store.moveBassNote(trackID, from: i, to: i + shift) }
                    dragIndex = nil; dragDX = 0
                }
        )
    }

    private var durationLabel: String {
        let n = max(notes.count, 1)
        let bars: Double = track?.bassTiming == .free ? 1.0 : 4.0 / Double(n)
        if bars >= 1, bars.rounded() == bars { return "\(Int(bars)) bar\(Int(bars) == 1 ? "" : "s")" }
        if bars == 0.5 { return "½ bar" }
        return String(format: "%.1f bars", bars)
    }

    // MARK: Timing toggle

    private var controlRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(ChordTiming.allCases, id: \.self) { mode in
                    let on = track?.bassTiming == mode
                    Text(mode.label).mono(10, .semibold).tracking(1)
                        .foregroundStyle(on ? Color(hex: "0c0e14") : Theme.textDim)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(on ? layer.accent : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                        .onTapGesture { store.setBassTiming(trackID, mode) }
                }
            }
            .padding(3)
            .background(Theme.panel, in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline(0.08)))

            Spacer()

            if !notes.isEmpty {
                Button { store.clearBassNotes(trackID) } label: {
                    Text("CLEAR").mono(10, .semibold).tracking(1).foregroundStyle(Theme.textDim)
                        .padding(.vertical, 7).padding(.horizontal, 13)
                        .background(Theme.panel, in: Capsule())
                        .overlay(Capsule().stroke(Theme.hairline(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }

    // MARK: Pitch / volume / footer

    private var pitchRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pitch").ui(14, .semibold).foregroundStyle(Theme.textSecondary)
                Text("transpose the whole line").mono(11).foregroundStyle(Theme.textDim)
            }
            Spacer()
            HStack(spacing: 14) {
                StepButton(symbol: "−") { store.pitchDown(trackID) }
                Text(pitchLabel).mono(18, .semibold).foregroundStyle(layer.accent)
                    .frame(minWidth: 48)
                StepButton(symbol: "+") { store.pitchUp(trackID) }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 18)
        .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: Theme.rRow))
        .overlay(RoundedRectangle(cornerRadius: Theme.rRow).stroke(Theme.hairline(0.05)))
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var pitchLabel: String {
        let n = store.pitchOf(trackID)
        return "\(n > 0 ? "+" : "")\(n) st"
    }

    private var footer: some View {
        HStack(spacing: 14) {
            ArcKnob(value: store.eqValue(trackID), accent: layer.accent, size: 52, lineWidth: 5,
                    trackColor: layer.tint(0.16), travel: 180,
                    onChange: { store.setEQ(trackID, $0) }) {
                VStack(spacing: 0) {
                    Text(Curves.hzLabel(store.eqValue(trackID))).mono(10).foregroundStyle(Theme.textPrimary)
                    Text("CUT").mono(7).tracking(1).foregroundStyle(Theme.textDim)
                }
            }
            Button { store.beginEditing(trackID); store.path.append(.synthEditor(trackID)) } label: {
                Text("⚙ EDIT SOUND").mono(12, .semibold).tracking(1).foregroundStyle(Color(hex: "7fa3d8"))
                    .frame(maxWidth: .infinity).padding(13)
                    .background(layer.tint(0.10), in: RoundedRectangle(cornerRadius: Theme.rPad))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rPad).stroke(layer.tint(0.4)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 22)
    }
}
