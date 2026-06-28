import Foundation

/// How a looped progression / line's time is divided across its steps (chords or bass notes).

enum ChordTiming: String, Codable, CaseIterable {
    case fit    // fixed 4-bar loop, chords split it evenly
    case free   // one bar per chord, loop grows with the count
    var label: String { self == .fit ? "FIT" : "FREE" }
}

/// One resolved chord in a progression, ready for the audio engine.
/// `rootSemis` = semitones above the key tonic (the bass follows it);
/// `midis` = absolute MIDI notes of the voicing.
struct ChordStep: Equatable {
    let rootSemis: Int
    let midis: [Int]
}

/// A reusable progression template — an ordered list of diatonic scale degrees (0…6).
/// Degrees (not absolute chords) so a template transposes with the key.
struct ChordTemplate: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var mood: String
    var degrees: [Int]
    var isUser: Bool = false
}

/// A single track in the sketch.
///
/// Every track is the *same* synth engine voice (an `Instrument`, or a `DrumSynth` for
/// drums) — only the front-end layout differs per `role`, which is what makes jamming
/// feel tailored. The sketch can hold any number of tracks of any role.
struct Track: Identifiable, Equatable {
    let id: UUID
    var role: LayerKind
    var name: String

    // Selection (role-dependent)
    var loopIdx: Int? = nil          // bass loop  OR  drum kit index
    // Chords: an ordered loop of voicings. Each voicing is a set of scale-step indices
    // (0 = tonic, 1 = 2nd … 7 = octave tonic), so it stays in-key and transposes with it.
    // Editing notes by step IS the voice-leading; the lines between chords show the motion.
    var chordVoicings: [[Int]] = []
    var timing: ChordTiming = .fit

    // Sound + mix (per-track — every track is independent)
    var params: SynthParams
    var eq: Double
    var volume: Double
    var shimmer: Bool
    var enabled: Bool = true
    var pitch: Int = 0               // bass transpose (semitones)
    // Bass: a hand-authored note line as ordered scale degrees (0…6, or 7 = octave tonic).
    // Empty = just the tonic. The selected loop supplies the rhythm/groove on each note.
    var bassNotes: [Int] = []
    var bassTiming: ChordTiming = .fit
    // Drums: editable [kick, snare, hat, clap] × 16-step pattern.
    var drumPattern: [[Bool]] = []

    init(id: UUID = UUID(), role: LayerKind, name: String) {
        self.id = id
        self.role = role
        self.name = name
        self.params = Track.defaultParams(role)
        self.eq = Track.defaultEQ(role)
        self.volume = Track.defaultVolume(role)
        self.shimmer = Track.defaultShimmer(role)
    }

    // MARK: Role capabilities (drive which front-end layout / controls a track gets)

    /// Bass & drums pick a loop/kit; chords pick a progression; lead is played live.
    var usesLoopPicker: Bool { role == .bass || role == .drums }
    var usesChords: Bool { role == .chords }
    var usesPads: Bool { role == .lead }
    var hasSound: Bool { role != .drums }   // drums = sample synth, no wavetable editor

    // MARK: Defaults per role (mirror the original hand-tuned engine voices)

    static func defaultParams(_ role: LayerKind) -> SynthParams {
        switch role {
        case .bass:
            return SynthParams(bright: 0.10, move: 0.0, space: 0.04, drive: 0.0,
                               oWave: 0.04, oUni: 0.0, fCut: 0.6, fRes: 0.0,
                               eA: 0.012, eD: 0.30, eS: 0.64, eR: 0.26,
                               fxSize: 0.4, fxShim: 0.2, fxMix: 0.03)
        case .chords:
            return SynthParams(bright: 0.52, move: 0.20, space: 0.55, drive: 0.0,
                               oWave: 0.70, oUni: 0.42, fCut: 0.62, fRes: 0.16,
                               eA: 0.20, eD: 0.45, eS: 0.82, eR: 0.85,
                               fxSize: 0.72, fxShim: 0.5, fxMix: 0.40)
        case .lead:
            return SynthParams(bright: 0.52, move: 0.10, space: 0.52, drive: 0.05,
                               oWave: 0.50, oUni: 0.30, fCut: 0.60, fRes: 0.14,
                               eA: 0.003, eD: 0.28, eS: 0.22, eR: 0.50,
                               fxSize: 0.62, fxShim: 0.58, fxMix: 0.50)
        case .drums:
            return SynthParams()
        }
    }

    static func defaultEQ(_ role: LayerKind) -> Double {
        switch role { case .bass: return 0.5; case .chords: return 0.7; case .drums: return 0.62; case .lead: return 0.6 }
    }
    static func defaultVolume(_ role: LayerKind) -> Double {
        switch role { case .bass: return 0.85; case .chords: return 0.8; case .drums: return 0.85; case .lead: return 0.82 }
    }
    static func defaultShimmer(_ role: LayerKind) -> Bool {
        switch role { case .bass: return false; case .chords: return true; case .drums: return false; case .lead: return true }
    }
}
