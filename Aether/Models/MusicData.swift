import Foundation

// MARK: - Static catalog data (mirrors the design prototype)

struct LoopInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let meta: String
}

struct Progression: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let mood: String
    let chords: [String]
    /// Roman-numeral-ish root semitone offsets from A (for audio), per chord.
    let roots: [Int]
    /// Chord quality intervals (semitone sets) per chord, for audio.
    let voicings: [[Int]]
}

struct Preset: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    let tag: String          // LEAD / BASS / CHORDS / PAD / —
    let col: LayerKind       // accent color owner
    let desc: String
    var params: SynthParams? = nil  // saved sound snapshot
}

enum MusicData {
    static let bassLoops: [LoopInfo] = [
        .init(name: "Sub Roller", meta: "OFFBEAT"),
        .init(name: "Reese Pulse", meta: "GLIDE"),
        .init(name: "Deep Saw", meta: "WARM"),
        .init(name: "808 Glide", meta: "TRAP-ish"),
        .init(name: "Pluck Bass", meta: "TIGHT"),
    ]

    static let drumLoops: [LoopInfo] = [
        .init(name: "Deep 4x4", meta: "CLASSIC"),
        .init(name: "Garage Skip", meta: "SWUNG"),
        .init(name: "Breakbeat", meta: "BROKEN"),
        .init(name: "Minimal", meta: "SPARSE"),
        .init(name: "Peak Time", meta: "DRIVING"),
    ]

    // A natural-minor diatonic chords. roots are semitones above A (0=A).
    // qualities: min triad [0,3,7], maj [0,4,7], min7 [0,3,7,10], maj7 [0,4,7,11], 6 [0,4,7,9], dom-ish.
    static let progressions: [Progression] = [
        .init(name: "Emotive", mood: "WARM",
              chords: ["Am7", "Fmaj7", "Cmaj7", "G6"],
              roots: [0, 8, 3, 10],
              voicings: [[0,3,7,10],[0,4,7,11],[0,4,7,11],[0,4,7,9]]),
        .init(name: "Nightfall", mood: "DARK",
              chords: ["Am", "C", "G", "Em"],
              roots: [0, 3, 10, 7],
              voicings: [[0,3,7],[0,4,7],[0,4,7],[0,3,7]]),
        .init(name: "Drifting", mood: "DREAMY",
              chords: ["Dm7", "Am7", "B♭", "F"],
              roots: [5, 0, 1, 8],
              voicings: [[0,3,7,10],[0,3,7,10],[0,4,7],[0,4,7]]),
        .init(name: "Sunrise", mood: "UPLIFT",
              chords: ["Fmaj7", "Am7", "Dm7", "G"],
              roots: [8, 0, 5, 10],
              voicings: [[0,4,7,11],[0,3,7,10],[0,3,7,10],[0,4,7]]),
    ]

    // Progression templates as ordered diatonic scale degrees (0…6), so they transpose
    // with the key. These light up on the circle of fifths and seed the sequence strip.
    static let chordTemplates: [ChordTemplate] = [
        .init(name: "Emotive",  mood: "WARM",   degrees: [0, 5, 2, 6]),   // i  VI  III VII
        .init(name: "Nightfall", mood: "DARK",  degrees: [0, 2, 6, 4]),   // i  III VII v
        .init(name: "Drifting", mood: "DREAMY", degrees: [3, 0, 1, 5]),   // iv i   II  VI
        .init(name: "Sunrise",  mood: "UPLIFT", degrees: [5, 0, 3, 6]),   // VI i   iv  VII
    ]

    // Diatonic letters of A minor (ascending), used for the pad grid labels.
    static let scaleLetters = ["A", "B", "C", "D", "E", "F", "G"]
    // Semitone offset from A for each diatonic degree (natural minor).
    static let scaleSemitones = [0, 2, 3, 5, 7, 8, 10]

    // 16-step drum patterns per drum loop index (1 = hit).
    static let drumPatterns: [[Int]] = [
        [1,0,0,0,1,0,0,0,1,0,0,0,1,0,1,0],
        [1,0,1,1,0,1,0,0,1,0,1,0,0,1,1,0],
        [1,0,0,1,0,1,1,0,0,1,0,0,1,0,1,1],
        [1,0,0,0,0,0,1,0,1,0,0,0,0,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1],
    ]

    static let defaultPresets: [Preset] = [
        .init(name: "Aurora Pluck", tag: "LEAD", col: .lead, desc: "Bright WT · Shimmer 55 · Soft env"),
        .init(name: "Deep Sub", tag: "BASS", col: .bass, desc: "Sine + sub · LP 180Hz · Tight"),
        .init(name: "Glass Keys", tag: "CHORDS", col: .chords, desc: "Bell WT · Long release · Wide"),
        .init(name: "Velvet Saw", tag: "PAD", col: .chords, desc: "Warm saw · Shimmer 80 · Slow"),
    ]
}

// MARK: - Synth parameter block (all normalized 0...1 except where noted)

struct SynthParams: Equatable, Codable {
    var bright: Double = 0.6
    var move: Double = 0.45
    var space: Double = 0.7
    var drive: Double = 0.35
    var oWave: Double = 0.35
    var oUni: Double = 0.6
    var fCut: Double = 0.55
    var fRes: Double = 0.32
    var eA: Double = 0.18
    var eH: Double = 0.0      // hold — time the envelope stays at peak before decay (easy plucks)
    var eD: Double = 0.4
    var eS: Double = 0.62
    var eR: Double = 0.5
    var fxSize: Double = 0.7
    var fxShim: Double = 0.55
    var fxMix: Double = 0.42

    subscript(key: String) -> Double {
        get {
            switch key {
            case "bright": return bright
            case "move": return move
            case "space": return space
            case "drive": return drive
            case "oWave": return oWave
            case "oUni": return oUni
            case "fCut": return fCut
            case "fRes": return fRes
            case "eA": return eA
            case "eH": return eH
            case "eD": return eD
            case "eS": return eS
            case "eR": return eR
            case "fxSize": return fxSize
            case "fxShim": return fxShim
            case "fxMix": return fxMix
            default: return 0
            }
        }
        set {
            switch key {
            case "bright": bright = newValue
            case "move": move = newValue
            case "space": space = newValue
            case "drive": drive = newValue
            case "oWave": oWave = newValue
            case "oUni": oUni = newValue
            case "fCut": fCut = newValue
            case "fRes": fRes = newValue
            case "eA": eA = newValue
            case "eH": eH = newValue
            case "eD": eD = newValue
            case "eS": eS = newValue
            case "eR": eR = newValue
            case "fxSize": fxSize = newValue
            case "fxShim": fxShim = newValue
            case "fxMix": fxMix = newValue
            default: break
            }
        }
    }

}

// Custom decode in an extension keeps the synthesized memberwise init available everywhere.
extension SynthParams {
    enum CodingKeys: String, CodingKey {
        case bright, move, space, drive, oWave, oUni, fCut, fRes, eA, eH, eD, eS, eR, fxSize, fxShim, fxMix
    }

    // Tolerant decode so presets saved before a field existed still load.
    init(from decoder: Decoder) throws {
        let def = SynthParams()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func d(_ k: CodingKeys, _ fb: Double) -> Double { (try? c.decode(Double.self, forKey: k)) ?? fb }
        self.init(
            bright: d(.bright, def.bright), move: d(.move, def.move), space: d(.space, def.space), drive: d(.drive, def.drive),
            oWave: d(.oWave, def.oWave), oUni: d(.oUni, def.oUni), fCut: d(.fCut, def.fCut), fRes: d(.fRes, def.fRes),
            eA: d(.eA, def.eA), eH: d(.eH, def.eH), eD: d(.eD, def.eD), eS: d(.eS, def.eS), eR: d(.eR, def.eR),
            fxSize: d(.fxSize, def.fxSize), fxShim: d(.fxShim, def.fxShim), fxMix: d(.fxMix, def.fxMix)
        )
    }
}
