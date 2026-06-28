import SwiftUI

struct LeadJamScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let trackID: UUID
    private let lead = LayerKind.lead

    private var track: Track? { store.track(trackID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            controlRow
            padGrid
            ribbon
        }
        .screen()
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                BackButton { dismiss() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track?.name ?? "LEAD").ui(17, .semibold).tracking(0.4).foregroundStyle(lead.accent)
                    Text("\(store.presetName.uppercased()) · \(store.keyName)").mono(11)
                        .foregroundStyle(Theme.textDim)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                Button { store.beginEditing(trackID); store.path.append(.synthEditor(trackID)) } label: {
                    Text("⚙ SOUND").mono(11, .semibold).tracking(1).foregroundStyle(lead.accent)
                        .padding(.vertical, 7).padding(.horizontal, 11)
                        .background(lead.tint(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(lead.tint(0.4)))
                }
                .buttonStyle(.plain)
                EQBars(accent: lead.accent, barHeight: 16, period: 0.6)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: Control row

    private var controlRow: some View {
        HStack(spacing: 8) {
            Text("SCALE · \(store.keyName)").mono(11).tracking(1).foregroundStyle(lead.accent)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(9)
                .background(lead.tint(0.12), in: RoundedRectangle(cornerRadius: Theme.rPill))
                .overlay(RoundedRectangle(cornerRadius: Theme.rPill).stroke(lead.tint(0.35)))

            octButton("−") { store.octDown() }
            Text("OCT \(store.octave)").mono(11).tracking(0.5).foregroundStyle(Theme.textSecondary)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.rPill))
                .overlay(RoundedRectangle(cornerRadius: Theme.rPill).stroke(Theme.hairline(0.07)))
            octButton("+") { store.octUp() }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    private func octButton(_ s: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s).font(.system(size: 16)).foregroundStyle(Theme.textMuted)
                .frame(width: 44).padding(.vertical, 9)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.rPill))
                .overlay(RoundedRectangle(cornerRadius: Theme.rPill).stroke(Theme.hairline(0.07)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Pad grid

    private var padGrid: some View {
        ZStack {
            VStack(spacing: 9) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 9) {
                        ForEach(0..<4, id: \.self) { col in
                            padView(row * 4 + col)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            // Transparent multitouch layer on top — true polyphony (hold chords).
            MultiTouchPadGrid(
                rows: 4, cols: 4,
                onDown: { d in store.padDown(d, midi: padInfo(d).midi, track: trackID) },
                onUp: { d in store.padUp(d, track: trackID) }
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxHeight: .infinity)
    }

    private func padInfo(_ d: Int) -> (note: String, deg: String, midi: Int, isRoot: Bool) {
        let row = d / 4, col = d % 4
        let rank = (3 - row) * 4 + col
        let degree = rank % 7
        let oct = store.octave + rank / 7
        let note = store.key.letterOnly(degree: degree)
        let midi = store.key.midi(degree: degree, octave: oct)
        return (note, "\(note)\(oct)", midi, degree == 0)
    }

    private func padView(_ d: Int) -> some View {
        let info = padInfo(d)
        let active = store.padActive.contains(d)
        return VStack(spacing: 2) {
            Text(info.note).ui(17, .semibold)
                .foregroundStyle(active ? Color(hex: "1a1206") : Theme.textPrimary)
            Text(info.deg).mono(9)
                .foregroundStyle(active ? Color(hex: "1a1206").opacity(0.6) : Theme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(padFill(active: active, isRoot: info.isRoot),
                    in: RoundedRectangle(cornerRadius: Theme.rPad))
        .overlay(RoundedRectangle(cornerRadius: Theme.rPad)
            .stroke(padStroke(active: active, isRoot: info.isRoot)))
        .shadow(color: active ? lead.accent.opacity(0.6) : .clear, radius: active ? 12 : 0)
        .scaleEffect(active ? 0.96 : 1)
        .animation(.easeOut(duration: 0.05), value: active)
        // Touch handled by the MultiTouchPadGrid overlay (polyphonic).
    }

    private func padFill(active: Bool, isRoot: Bool) -> Color {
        if active { return lead.accent }
        return isRoot ? lead.tint(0.10) : Theme.panel
    }
    private func padStroke(active: Bool, isRoot: Bool) -> Color {
        if active { return Color(hex: "f0d39a") }
        return isRoot ? lead.tint(0.4) : Theme.hairline(0.06)
    }

    // MARK: Filter-morph ribbon

    private var ribbon: some View {
        VStack(spacing: 7) {
            HStack {
                Text("FILTER MORPH").mono(10).tracking(1).foregroundStyle(Theme.textDim)
                Spacer()
                Text(Curves.hzLabel(store.eqValue(trackID))).mono(10).foregroundStyle(lead.accent)
            }
            GeometryReader { geo in
                let pct = store.eqValue(trackID)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.rPad).fill(Theme.panel)
                        .overlay(RoundedRectangle(cornerRadius: Theme.rPad).stroke(Theme.hairline(0.07)))
                    LinearGradient(colors: [lead.tint(0.10), lead.tint(0.28)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * pct)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rPad))
                    Rectangle().fill(lead.accent).frame(width: 3)
                        .shadow(color: lead.accent, radius: 6)
                        .offset(x: geo.size.width * pct - 1.5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            store.setEQ(trackID, g.location.x / geo.size.width)
                        }
                )
            }
            .frame(height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }
}
