import SwiftUI

// MARK: - Detail screen header (back · layer title · subtitle)

struct DetailHeader: View {
    let layer: LayerKind
    var title: String? = nil
    let subtitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BackButton(action: onBack)
            VStack(alignment: .leading, spacing: 2) {
                Text(title ?? layer.title).ui(17, .semibold).tracking(0.4).foregroundStyle(layer.accent)
                Text(subtitle).mono(11).foregroundStyle(Theme.textDim)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Mono section caption

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).mono(11).tracking(1.5).foregroundStyle(Theme.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Horizontal loop/kit swatch strip

struct LoopSwatchStrip: View {
    let loops: [LoopInfo]
    let selected: Int?
    let layer: LayerKind
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(loops.enumerated()), id: \.element.id) { idx, loop in
                    let sel = idx == selected
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loop.name).ui(13, .semibold)
                            .foregroundStyle(sel ? Theme.textPrimary : Theme.textMuted)
                        Text(loop.meta).mono(10)
                            .foregroundStyle(sel ? layer.tint(0.85) : Theme.textFaint)
                    }
                    .frame(minWidth: 108, alignment: .leading)
                    .padding(.vertical, 13).padding(.horizontal, 15)
                    .background(sel ? layer.tint(0.14) : Theme.panel,
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(sel ? layer.accent : Theme.hairline(0.06)))
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(idx) }
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 64)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Horizontal volume fader

struct VolumeFader: View {
    let value: Double
    let accent: Color
    var height: CGFloat = 6
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(accent.opacity(0.85))
                    .frame(width: max(0, min(geo.size.width, geo.size.width * value)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in onChange(min(1, max(0, g.location.x / geo.size.width))) }
            )
        }
        .frame(height: height)
    }
}

/// A labelled volume row for the detail screens.
struct VolumeRow: View {
    let layer: LayerKind
    let value: Double
    let onChange: (Double) -> Void
    var body: some View {
        HStack(spacing: 12) {
            Text("VOL").mono(10).tracking(1).foregroundStyle(Theme.textDim)
            VolumeFader(value: value, accent: layer.accent, height: 8, onChange: onChange)
            Text("\(Int(value * 100))").mono(11).foregroundStyle(Theme.textSecondary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: Theme.rRow))
        .overlay(RoundedRectangle(cornerRadius: Theme.rRow).stroke(Theme.hairline(0.05)))
    }
}

// MARK: - Big EQ filter card (curve + 88px knob + helper text)

struct BigEQFilterCard: View {
    let layer: LayerKind
    let helper: [String]
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionLabel("EQ · FILTER").padding(.bottom, 6)
            GeometryReader { geo in
                Curves.eqCurve(cut: value, rect: geo.size)
                    .stroke(layer.accent, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    .shadow(color: layer.tint(0.5), radius: 3)
            }
            .frame(height: 54)

            HStack(spacing: 20) {
                ArcKnob(value: value, accent: layer.accent, size: 88, lineWidth: 5,
                        trackColor: layer.tint(0.16), travel: 180, onChange: onChange) {
                    VStack(spacing: 1) {
                        Text(Curves.hzLabel(value)).mono(15).foregroundStyle(Theme.textPrimary)
                        Text("CUTOFF").mono(9).tracking(1).foregroundStyle(Theme.textDim)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(helper.enumerated()), id: \.offset) { i, line in
                        Text(line).mono(11)
                            .foregroundStyle(i == helper.count - 1 ? layer.tint(0.85) : Theme.textDim)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.hairline(0.05)))
    }
}
