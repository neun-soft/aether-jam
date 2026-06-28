import SwiftUI

// MARK: - Arc knob (vertical-drag, 270° gauge)

struct ArcKnob<Center: View>: View {
    let value: Double
    var accent: Color
    var size: CGFloat = 70
    var lineWidth: CGFloat = 6
    var trackColor: Color = Color.white.opacity(0.07)
    var travel: CGFloat = 170
    let onChange: (Double) -> Void
    @ViewBuilder var center: () -> Center

    @State private var startValue: Double? = nil

    var body: some View {
        ZStack {
            Curves.arcTrack(in: size)
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Curves.arc(value: value, in: size)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            center()
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if startValue == nil { startValue = value }
                    let base = startValue ?? value
                    let v = base + Double(-g.translation.height / travel)
                    onChange(min(1, max(0, v)))
                }
                .onEnded { _ in startValue = nil }
        )
    }
}

extension ArcKnob where Center == EmptyView {
    init(value: Double, accent: Color, size: CGFloat = 70, lineWidth: CGFloat = 6,
         trackColor: Color = Color.white.opacity(0.07), travel: CGFloat = 170,
         onChange: @escaping (Double) -> Void) {
        self.init(value: value, accent: accent, size: size, lineWidth: lineWidth,
                  trackColor: trackColor, travel: travel, onChange: onChange) { EmptyView() }
    }
}

// MARK: - Animated EQ "playing" bars

struct EQBars: View {
    var accent: Color
    var barHeight: CGFloat = 18
    var barWidth: CGFloat = 3
    var period: Double = 0.7

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                EQBar(accent: accent, height: barHeight, width: barWidth,
                      period: period, delay: Double(i) * 0.2)
            }
        }
        .frame(height: barHeight, alignment: .bottom)
    }
}

private struct EQBar: View {
    var accent: Color
    var height: CGFloat
    var width: CGFloat
    var period: Double
    var delay: Double
    @State private var up = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accent)
            .frame(width: width, height: height)
            .scaleEffect(x: 1, y: up ? 1 : 0.3, anchor: .bottom)
            .onAppear {
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true).delay(delay)) {
                    up = true
                }
            }
    }
}

// MARK: - Small +/− step button

struct StepButton: View {
    let symbol: String
    var size: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20))
                .foregroundStyle(Theme.textMuted)
                .frame(width: size, height: size)
                .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.rPill))
                .overlay(RoundedRectangle(cornerRadius: Theme.rPill).stroke(Theme.hairline(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Back button (chevron tile)

struct BackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("‹")
                .font(.system(size: 22))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 30, height: 30)
                .overlay(RoundedRectangle(cornerRadius: Theme.rSmall).stroke(Theme.hairline(0.10)))
        }
        .buttonStyle(.plain)
    }
}
