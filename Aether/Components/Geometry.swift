import SwiftUI

/// Path builders mirroring the prototype's exact curve math, scaled into a target rect.
enum Curves {

    // 270° arc gauge: center (44,44), r=32 in an 88×88 box, start −135°, sweep val·270°.
    // Point: x = cx + r·sin(a), y = cy − r·cos(a), a in degrees.
    static func arc(value: Double, in size: CGFloat) -> Path {
        let scale = size / 88.0
        let cx = 44.0, cy = 44.0, r = 32.0
        let v = max(0, min(1, value))
        var p = Path()
        let steps = 96
        let a0 = -135.0
        let a1 = -135.0 + v * 270.0
        for i in 0...steps {
            let a = (a0 + (a1 - a0) * Double(i) / Double(steps)) * .pi / 180
            let x = (cx + r * sin(a)) * scale
            let y = (cy - r * cos(a)) * scale
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }

    static func arcTrack(in size: CGFloat) -> Path { arc(value: 1, in: size) }

    // EQ filter response curve. prototype W,H with preserveAspectRatio="none" → stretch to rect.
    static func eqCurve(cut: Double, rect: CGSize, srcW: Double = 345, srcH: Double = 60) -> Path {
        var p = Path()
        let pad = 4.0
        var first = true
        var x = 0.0
        while x <= srcW {
            let f = x / srcW
            let ratio = f / (cut + 0.001)
            var mag = ratio < 1 ? 1.0 : 1.0 / (1.0 + pow((ratio - 1) * 5, 2))
            mag += 0.28 * exp(-pow((f - cut) * 12, 2))
            mag = min(1.25, mag)
            let y = (srcH - pad) - (mag / 1.25) * (srcH - 2 * pad)
            let px = f * rect.width
            let py = (y / srcH) * rect.height
            if first { p.move(to: CGPoint(x: px, y: py)); first = false }
            else { p.addLine(to: CGPoint(x: px, y: py)) }
            x += 5
        }
        return p
    }

    // Oscillator wavetable morph polyline.
    static func osc(morph m: Double, rect: CGSize, srcW: Double = 345, srcH: Double = 64) -> Path {
        var p = Path()
        var first = true
        var x = 0.0
        while x <= srcW {
            let ph = x / srcW * Double.pi * 4
            let v = sin(ph) * (1 - m * 0.55) + sin(ph * 3) * 0.32 * m + sin(ph * 2) * 0.22 * m
            let y = srcH / 2 - v * (srcH / 2 * 0.82)
            let px = (x / srcW) * rect.width
            let py = (y / srcH) * rect.height
            if first { p.move(to: CGPoint(x: px, y: py)); first = false }
            else { p.addLine(to: CGPoint(x: px, y: py)) }
            x += 3
        }
        return p
    }

    struct ADSR { var stroke: Path; var fill: Path }

    static func adsr(a: Double, d: Double, s: Double, r: Double, rect: CGSize) -> ADSR {
        let srcW = 320.0, srcH = 78.0, pad = 6.0, x0 = 3.0
        let xa = x0 + a * 0.32 * srcW
        let xd = xa + d * 0.28 * srcW
        let xs = srcW * 0.70
        let xr = min(srcW - 2, xs + (srcW - xs) * (0.35 + r * 0.65))
        let susY = (srcH - pad) - s * (srcH - 2 * pad)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: (x / srcW) * rect.width, y: (y / srcH) * rect.height)
        }
        let nodes = [pt(x0, srcH - pad), pt(xa, pad), pt(xd, susY), pt(xs, susY), pt(xr, srcH - pad)]
        var stroke = Path()
        stroke.addLines(nodes)
        var fill = Path()
        fill.move(to: pt(x0, srcH - pad))
        for n in nodes { fill.addLine(to: n) }
        fill.addLine(to: pt(xr, srcH - pad))
        fill.closeSubpath()
        return ADSR(stroke: stroke, fill: fill)
    }

    // Filled loop waveform polygon from a seed (mirrors wavePoly).
    static func waveform(seed: Double, rect: CGSize, srcW: Double = 345, srcH: Double = 56) -> Path {
        let cy = srcH / 2
        var top: [CGPoint] = []
        var bot: [CGPoint] = []
        var x = 0.0
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: (x / srcW) * rect.width, y: (y / srcH) * rect.height)
        }
        while x <= srcW {
            let a = (srcH / 2 - 3) * (0.22 + 0.78 * abs(sin(x * 0.21 + seed) * sin(x * 0.066 + seed * 1.7)))
            top.append(pt(x, cy - a))
            bot.append(pt(x, cy + a))
            x += 4
        }
        var p = Path()
        p.addLines(top)
        for q in bot.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }

    // Filter cutoff → Hz label. value→cutoff Hz via 60·2^(value·7.5).
    static func hzLabel(_ v: Double) -> String {
        let hz = Int((60 * pow(2, v * 7.5)).rounded())
        return hz >= 1000 ? String(format: "%.1fk", Double(hz) / 1000) : "\(hz)"
    }

    static func cutoffHz(_ v: Double) -> Double { 60 * pow(2, v * 7.5) }
}
