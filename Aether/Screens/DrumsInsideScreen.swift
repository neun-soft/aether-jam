import SwiftUI

struct DrumsInsideScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let trackID: UUID
    private let layer = LayerKind.drums

    private var track: Track? { store.track(trackID) }
    private var pattern: [[Bool]] { store.drumPatternOf(trackID) }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(layer: layer, title: track?.name ?? layer.title,
                         subtitle: store.loopName(track ?? Track(role: .drums, name: ""))) { dismiss() }

            patternGrid
            patternControls

            SectionLabel("KIT / GROOVE").padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
            LoopSwatchStrip(loops: store.drumLoops, selected: track?.loopIdx, layer: layer) {
                store.selectLoop(trackID, $0)
            }

            Spacer(minLength: 0)
            footer
        }
        .screen()
    }

    // MARK: Editable 4-lane step grid

    private var patternGrid: some View {
        Group {
            if pattern.count < 4 {
                VStack(spacing: 8) {
                    Text("No kit yet").ui(15, .semibold).foregroundStyle(Theme.textSecondary)
                    Text("Pick a kit/groove below, then tap the cells to build the beat.")
                        .mono(11).foregroundStyle(Theme.textFaint).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150).padding(.horizontal, 30)
            } else {
                VStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { lane in
                        HStack(spacing: 3) {
                            Text(AppStore.drumLaneNames[lane]).mono(8).tracking(0.5)
                                .foregroundStyle(Theme.textDim)
                                .frame(width: 34, alignment: .leading)
                            ForEach(0..<16, id: \.self) { step in
                                cell(lane: lane, step: step)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
        }
    }

    private func cell(lane: Int, step: Int) -> some View {
        let on = pattern[lane][step]
        let beat = step % 4 == 0
        return RoundedRectangle(cornerRadius: 4)
            .fill(on ? layer.accent : (beat ? Color.white.opacity(0.10) : Color.white.opacity(0.04)))
            .frame(height: 24)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? layer.accent : Color.clear))
            .shadow(color: on ? layer.tint(0.4) : .clear, radius: on ? 3 : 0)
            .contentShape(Rectangle())
            .onTapGesture { store.toggleDrumCell(trackID, lane: lane, step: step) }
    }

    private var patternControls: some View {
        HStack {
            Text("16 STEPS · TAP TO TOGGLE").mono(9).tracking(1).foregroundStyle(Theme.textFaint)
            Spacer()
            if pattern.count == 4 {
                Button { store.clearDrumPattern(trackID) } label: {
                    Text("CLEAR").mono(10, .semibold).tracking(1).foregroundStyle(Theme.textDim)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Theme.panel, in: Capsule())
                        .overlay(Capsule().stroke(Theme.hairline(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            ArcKnob(value: store.eqValue(trackID), accent: layer.accent, size: 52, lineWidth: 5,
                    trackColor: layer.tint(0.16), travel: 180,
                    onChange: { store.setEQ(trackID, $0) }) {
                VStack(spacing: 0) {
                    Text(Curves.hzLabel(store.eqValue(trackID))).mono(10).foregroundStyle(Theme.textPrimary)
                    Text("FILTER").mono(7).tracking(1).foregroundStyle(Theme.textDim)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("VOLUME").mono(9).tracking(1.5).foregroundStyle(Theme.textDim)
                VolumeFader(value: store.volumeOf(trackID), accent: layer.accent, height: 5) {
                    store.setVolume(trackID, $0)
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 22)
    }
}
