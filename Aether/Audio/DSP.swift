import Foundation

// MARK: - Utility

@inline(__always) func midiToHz(_ midi: Double) -> Double { 440.0 * pow(2.0, (midi - 69.0) / 12.0) }
@inline(__always) func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
@inline(__always) func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

/// Flush near-zero values to 0. Denormal floats (tiny decaying tails) make the CPU 10–100×
/// slower, which can overload the audio thread and kill the stream — this is the guardrail.
@inline(__always) func flush(_ x: Double) -> Double { abs(x) < 1e-15 ? 0 : x }

// MARK: - Morphing wavetable oscillator (sine ↔ bandlimited saw)
// A precomputed sine table and an additive (bandlimited) saw table; `morph` (0…1) blends
// between them. The saw is harmonically rich, so the low-pass filter has real harmonics to
// shape — that's what makes the filters audibly work and the tone sound musical.

enum WaveTables {
    static let size = 2048
    static let mask = size - 1
    private static let harmonics = 28

    private static func build(_ amp: (Int) -> Double) -> [Double] {
        var t = [Double](repeating: 0, count: size)
        for k in 1...harmonics {
            let a = amp(k)
            if a == 0 { continue }
            let w = 2.0 * .pi * Double(k) / Double(size)
            for i in 0..<size { t[i] += a * sin(w * Double(i)) }
        }
        let peak = t.map { abs($0) }.max() ?? 1
        return peak > 0 ? t.map { $0 / peak } : t
    }

    // Four bandlimited single-cycle tables, ordered by brightness.
    static let sine = build { $0 == 1 ? 1 : 0 }
    static let triangle = build { k in k % 2 == 1 ? (k % 4 == 1 ? 1.0 : -1.0) / Double(k * k) : 0 }
    static let saw = build { 1.0 / Double($0) }
    static let square = build { k in k % 2 == 1 ? 1.0 / Double(k) : 0 }
    private static let ramp: [[Double]] = [sine, triangle, saw, square]

    /// WT POS (0…1) sweeps continuously through sine → triangle → saw → square.
    @inline(__always) static func sample(phase: Double, morph m: Double) -> Double {
        let p = phase - floor(phase)
        let x = p * Double(size)
        let i = Int(x) & mask
        let i2 = (i + 1) & mask
        let f = x - Double(Int(x))

        let segs = ramp.count - 1               // 3 segments
        let pos = max(0, min(0.99999, m)) * Double(segs)
        let s = Int(pos)
        let blend = pos - Double(s)
        let a = ramp[s], b = ramp[s + 1]
        let va = a[i] * (1 - f) + a[i2] * f
        let vb = b[i] * (1 - f) + b[i2] * f
        return va * (1 - blend) + vb * blend
    }
}

@inline(__always) func wavetableSample(phase: Double, morph m: Double) -> Double {
    WaveTables.sample(phase: phase, morph: m)
}

// MARK: - ADSR envelope

final class ADSREnvelope {
    enum Stage { case idle, attack, hold, decay, sustain, release }
    private(set) var stage: Stage = .idle
    private var value: Double = 0
    private var sampleRate: Double
    private var holdElapsed: Double = 0

    // times in seconds, sustain 0…1
    var attack: Double = 0.01
    var hold: Double = 0       // time held at peak before decay (AHDSR)
    var decay: Double = 0.2
    var sustain: Double = 0.7
    var release: Double = 0.3

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    var isActive: Bool { stage != .idle }

    func gateOn() { stage = .attack; holdElapsed = 0 }
    func gateOff() { if stage != .idle { stage = .release } }
    func reset() { stage = .idle; value = 0 }

    @inline(__always) func process() -> Double {
        switch stage {
        case .idle:
            return 0
        case .attack:
            let inc = attack <= 0 ? 1 : 1.0 / (attack * sampleRate)
            value += inc
            if value >= 1 { value = 1; stage = hold > 0 ? .hold : .decay; holdElapsed = 0 }
        case .hold:
            value = 1
            holdElapsed += 1.0 / sampleRate
            if holdElapsed >= hold { stage = .decay }
        case .decay:
            let rate = decay <= 0 ? 1 : 1.0 / (decay * sampleRate)
            value -= (1 - sustain) * rate
            if value <= sustain { value = sustain; stage = .sustain }
        case .sustain:
            value = sustain
        case .release:
            let rate = release <= 0 ? 1 : 1.0 / (release * sampleRate)
            value -= sustain <= 0 ? rate : (sustain * rate)
            value -= rate * 0.0001
            if value <= 0 { value = 0; stage = .idle }
        }
        return value
    }
}

// MARK: - State-variable filter (low-pass) with resonance

final class SVFilter {
    private var ic1eq: Double = 0
    private var ic2eq: Double = 0
    private var g: Double = 0
    private var k: Double = 0
    private var a1: Double = 0, a2: Double = 0, a3: Double = 0
    private let sampleRate: Double

    init(sampleRate: Double) { self.sampleRate = sampleRate; set(cutoff: 1200, resonance: 0.2) }

    func set(cutoff: Double, resonance: Double) {
        let fc = min(max(cutoff, 20), sampleRate * 0.45)
        g = tan(.pi * fc / sampleRate)
        k = 2.0 - 1.8 * min(max(resonance, 0), 0.98)   // lower k = more resonance
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    }

    @inline(__always) func process(_ x: Double) -> Double {
        let v3 = x - ic2eq
        let v1 = a1 * ic1eq + a2 * v3
        let v2 = ic2eq + a2 * ic1eq + a3 * v3
        ic1eq = flush(2 * v1 - ic1eq)
        ic2eq = flush(2 * v2 - ic2eq)
        return v2   // low-pass output
    }

    /// Both low-pass and high-pass from the same state (for the bipolar master DJ filter).
    @inline(__always) func processLPHP(_ x: Double) -> (lp: Double, hp: Double) {
        let v3 = x - ic2eq
        let v1 = a1 * ic1eq + a2 * v3
        let v2 = ic2eq + a2 * ic1eq + a3 * v3
        ic1eq = flush(2 * v1 - ic1eq)
        ic2eq = flush(2 * v2 - ic2eq)
        return (v2, x - k * v1 - v2)
    }

    func reset() { ic1eq = 0; ic2eq = 0 }
}

// MARK: - Polyphonic synth voice (unison wavetable + per-voice envelope)

final class Voice {
    var midi: Int = -1
    var active: Bool { env.isActive }
    private let sampleRate: Double
    private var phases: [Double] = [0, 0, 0, 0, 0, 0, 0]   // up to 7 unison
    private var detunes: [Double] = [0, 0, 0, 0, 0, 0, 0]
    let env: ADSREnvelope
    private var baseFreq: Double = 440
    private var voiceCount: Int = 1
    var velocity: Double = 1

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        env = ADSREnvelope(sampleRate: sampleRate)
    }

    func noteOn(midi: Int, voices: Int, detuneCents: Double, a: Double, h: Double, d: Double, s: Double, r: Double, vel: Double) {
        self.midi = midi
        baseFreq = midiToHz(Double(midi))
        voiceCount = min(max(voices, 1), 7)
        velocity = vel
        for i in 0..<7 {
            phases[i] = Double(i) * 0.13   // spread start phases
            let spread = voiceCount > 1 ? (Double(i) / Double(voiceCount - 1) - 0.5) * 2.0 : 0
            detunes[i] = pow(2.0, (spread * detuneCents) / 1200.0)
        }
        env.attack = a; env.hold = h; env.decay = d; env.sustain = s; env.release = r
        env.gateOn()
    }

    func noteOff() { env.gateOff() }

    @inline(__always) func render(morph: Double) -> Double {
        guard env.isActive else { return 0 }
        var sum = 0.0
        let inc = baseFreq / sampleRate
        for i in 0..<voiceCount {
            phases[i] += inc * detunes[i]
            if phases[i] >= 1 { phases[i] -= 1 }
            sum += wavetableSample(phase: phases[i], morph: morph)
        }
        let norm = sum / Double(voiceCount)
        return norm * env.process() * velocity
    }
}

// MARK: - Procedural drum synth (kick / snare / hat)

/// Per-kit timbre. Patterns live elsewhere; this just shapes the sounds.
struct DrumKit {
    var kickTuneLo: Double, kickTuneHi: Double, kickDecay: Double, kickClick: Double
    var snareTone: Double, snareDecay: Double, snareNoise: Double
    var hatDecay: Double, hatBright: Double

    static let kits: [DrumKit] = [
        // Deep 4x4 — deep round kick, soft warm hats, gentle clap (melodic/deep house)
        .init(kickTuneLo: 42, kickTuneHi: 104, kickDecay: 0.40, kickClick: 0.20,
              snareTone: 175, snareDecay: 0.16, snareNoise: 0.5, hatDecay: 0.038, hatBright: 5200),
        // Garage Skip — tight punchy kick, crisp hats
        .init(kickTuneLo: 52, kickTuneHi: 150, kickDecay: 0.22, kickClick: 0.6,
              snareTone: 210, snareDecay: 0.13, snareNoise: 0.8, hatDecay: 0.035, hatBright: 9000),
        // Breakbeat — snappy, brighter
        .init(kickTuneLo: 55, kickTuneHi: 170, kickDecay: 0.20, kickClick: 0.7,
              snareTone: 230, snareDecay: 0.18, snareNoise: 0.85, hatDecay: 0.05, hatBright: 8000),
        // Minimal — clean short
        .init(kickTuneLo: 48, kickTuneHi: 130, kickDecay: 0.26, kickClick: 0.4,
              snareTone: 200, snareDecay: 0.12, snareNoise: 0.6, hatDecay: 0.03, hatBright: 10000),
        // Peak Time — driving, hard click, bright
        .init(kickTuneLo: 50, kickTuneHi: 160, kickDecay: 0.24, kickClick: 0.8,
              snareTone: 220, snareDecay: 0.15, snareNoise: 0.9, hatDecay: 0.04, hatBright: 9500),
    ]
}

final class DrumSynth {
    private let sampleRate: Double
    private var rng: UInt32 = 22222
    private var kit = DrumKit.kits[0]

    // kick
    private var kPhase = 0.0, kAmp = 0.0, kPitch = 0.0, kClick = 0.0, kActive = false
    // snare
    private var sAmp = 0.0, sTonePh = 0.0, sActive = false
    // hats (closed/open share one voice)
    private var hAmp = 0.0, hDecay = 0.05, hActive = false
    private var hpZ1 = 0.0, hpX1 = 0.0, hpCoef = 0.9
    // clap
    private var cAmp = 0.0, cActive = false, cBursts = 0, cBurstT = 0.0

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    func setKit(_ idx: Int) { kit = DrumKit.kits[min(max(idx, 0), DrumKit.kits.count - 1)] }

    @inline(__always) private func noise() -> Double {
        rng = 1664525 &* rng &+ 1013904223
        return Double(Int32(bitPattern: rng)) / Double(Int32.max)
    }

    func triggerKick() { kActive = true; kAmp = 1; kPitch = 1; kPhase = 0; kClick = kit.kickClick }
    func triggerSnare() { sActive = true; sAmp = 1; sTonePh = 0 }
    func triggerHat(open: Bool = false) {
        hActive = true; hAmp = 1
        hDecay = open ? kit.hatDecay * 4.5 : kit.hatDecay
        // high-pass cutoff → coefficient
        let fc = kit.hatBright
        hpCoef = 1.0 / (1.0 + 2.0 * .pi * fc / sampleRate)
    }
    func triggerClap() { cActive = true; cAmp = 1; cBursts = 3; cBurstT = 0 }

    @inline(__always) func render() -> Double {
        var out = 0.0

        if kActive {
            let freq = lerp(kit.kickTuneLo, kit.kickTuneHi, kPitch)
            kPhase += freq / sampleRate
            if kPhase >= 1 { kPhase -= 1 }
            var k = sin(kPhase * 2 * .pi) * kAmp
            if kClick > 0 { k += noise() * kClick * 0.5; kClick -= 1.0 / (0.004 * sampleRate) }
            out += k * 0.9
            kAmp -= 1.0 / (kit.kickDecay * sampleRate)
            kPitch -= 1.0 / (0.03 * sampleRate)
            if kPitch < 0 { kPitch = 0 }
            if kAmp <= 0 { kActive = false; kAmp = 0 }
        }

        if sActive {
            sTonePh += kit.snareTone / sampleRate
            if sTonePh >= 1 { sTonePh -= 1 }
            let body = sin(sTonePh * 2 * .pi) * (1 - kit.snareNoise)
            let n = noise() * kit.snareNoise
            out += (n + body) * sAmp * 0.5
            sAmp -= 1.0 / (kit.snareDecay * sampleRate)
            if sAmp <= 0 { sActive = false; sAmp = 0 }
        }

        if hActive {
            let x = noise()
            // one-pole high-pass for a crisp tick
            let hp = hpCoef * (hpZ1 + x - hpX1)
            hpZ1 = hp; hpX1 = x
            out += hp * hAmp * 0.4
            hAmp -= 1.0 / (hDecay * sampleRate)
            if hAmp <= 0 { hActive = false; hAmp = 0 }
        }

        if cActive {
            cBurstT += 1.0 / sampleRate
            let env = cAmp
            out += noise() * env * 0.35
            cAmp -= 1.0 / (0.12 * sampleRate)
            if cAmp <= 0 { cActive = false; cAmp = 0 }
        }

        return out
    }
}

// MARK: - Shimmer reverb (Schroeder reverb + octave-up feedback shimmer)

final class ShimmerReverb {
    private let sampleRate: Double
    private var combs: [CombFilter] = []
    private var allpasses: [AllpassFilter] = []
    // shimmer pitch-up via a delay line read at double rate
    private var shimBuf: [Double]
    private var shimWrite = 0
    private var shimRead = 0.0
    private let shimLen: Int

    var decay: Double = 0.7     // size / tail length
    var shimmer: Double = 0.55
    var mix: Double = 0.4

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        // Larger comb set + longer delays = a bigger, lusher tail.
        let tunings = [1116, 1188, 1277, 1356, 1422, 1491].map { Int(Double($0) * sampleRate / 44100.0) }
        combs = tunings.map { CombFilter(length: $0) }
        allpasses = [556, 441, 341].map { AllpassFilter(length: Int(Double($0) * sampleRate / 44100.0)) }
        shimLen = Int(sampleRate * 0.5)
        shimBuf = [Double](repeating: 0, count: shimLen)
    }

    @inline(__always) func process(_ input: Double) -> Double {
        // Comb feedback strictly below 1 so the reverb always decays. Longer tail than before.
        let fb = 0.62 + 0.32 * clamp01(decay)   // max 0.94 — lush but convergent

        // Read the shimmer delay at 2× → an octave up.
        shimRead += 2.0
        if shimRead >= Double(shimLen) { shimRead -= Double(shimLen) }
        let ri = Int(shimRead) % shimLen
        let shimVoice = shimBuf[ri]

        var out = 0.0
        for c in combs { out += c.process(input, feedback: fb) }
        out *= 1.0 / Double(combs.count)
        for a in allpasses { out = a.process(out) }

        // Rising-shimmer feedback: store reverb tail + a BOUNDED fraction of the pitched
        // voice. Per-sample loop gain = shimFB < 1, so the octave stack always converges.
        let shimFB = 0.4 * clamp01(shimmer)             // < 1 guaranteed, gentler buildup
        shimBuf[shimWrite] = flush(out + shimVoice * shimFB)
        shimWrite = (shimWrite + 1) % shimLen

        // A tasteful octave layer on top of the reverb (not overpowering).
        return out + shimVoice * (0.18 + 0.4 * clamp01(shimmer))
    }
}

final class CombFilter {
    private var buf: [Double]
    private var idx = 0
    private var store = 0.0
    private let damp = 0.25
    init(length: Int) { buf = [Double](repeating: 0, count: max(1, length)) }
    @inline(__always) func process(_ input: Double, feedback: Double) -> Double {
        let out = buf[idx]
        store = flush(out * (1 - damp) + store * damp)
        buf[idx] = flush(input + store * feedback)
        idx = (idx + 1) % buf.count
        return out
    }
}

final class AllpassFilter {
    private var buf: [Double]
    private var idx = 0
    init(length: Int) { buf = [Double](repeating: 0, count: max(1, length)) }
    @inline(__always) func process(_ input: Double) -> Double {
        let bufout = buf[idx]
        let out = -input + bufout
        buf[idx] = flush(input + bufout * 0.5)
        idx = (idx + 1) % buf.count
        return out
    }
}

// MARK: - Master limiter (look-back peak follower → hard ceiling)

final class Limiter {
    private var gain = 1.0
    private let ceiling: Double
    private let attackCoef: Double
    private let releaseCoef: Double

    init(sampleRate: Double, ceiling: Double = 0.9) {
        self.ceiling = ceiling
        attackCoef = exp(-1.0 / (0.002 * sampleRate))   // 2ms
        releaseCoef = exp(-1.0 / (0.25 * sampleRate))   // 250ms
    }

    @inline(__always) func process(_ x: Double) -> Double {
        let a = abs(x)
        // target gain that would keep |x| under the ceiling
        let target = a > ceiling ? ceiling / a : 1.0
        // attack fast when we need to pull down, release slowly back up
        let coef = target < gain ? attackCoef : releaseCoef
        gain = coef * gain + (1 - coef) * target
        var y = x * gain
        // absolute brick wall as a final guarantee
        if y > ceiling { y = ceiling } else if y < -ceiling { y = -ceiling }
        return y
    }
}

// MARK: - Soft saturation (drive)

@inline(__always) func saturate(_ x: Double, drive: Double) -> Double {
    if drive < 0.001 { return x }   // fully transparent — no shaping on clean sounds (sub stays sine)
    let d = 1 + drive * 6
    return tanh(x * d) / tanh(d) * (0.6 + 0.4 * (1 - drive))
}
