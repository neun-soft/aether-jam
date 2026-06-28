import Foundation

// MARK: - Mode

enum Mode: String, CaseIterable, Codable {
    case minor, major
    var intervals: [Int] { self == .minor ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 4, 5, 7, 9, 11] }
    var label: String { self == .minor ? "MINOR" : "MAJOR" }
}

// MARK: - A diatonic chord, resolved in a key

struct ChordSpec: Identifiable, Equatable {
    let id = UUID()
    let degree: Int          // scale degree 0…6
    let name: String         // e.g. "Am", "C", "F♯°"
    let roman: String        // e.g. "i", "III", "vii°"
    let rootOffset: Int      // semitones above the key tonic
    let intervals: [Int]     // chord-tone intervals from the chord root (semitones)
}

// MARK: - MusicKey

struct MusicKey: Equatable, Codable {
    var root: Int            // pitch class, 0 = C
    var mode: Mode

    static let `default` = MusicKey(root: 9, mode: .minor)   // A minor

    // Display names per pitch class (flats chosen where idiomatic).
    static let pcNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static let letters = ["C", "D", "E", "F", "G", "A", "B"]
    static let letterPC = [0, 2, 4, 5, 7, 9, 11]

    static func pcName(_ pc: Int) -> String { pcNames[((pc % 12) + 12) % 12] }

    /// Chord-quality suffix inferred from a voicing's intervals.
    static func chordSuffix(_ intervals: [Int]) -> String {
        let s = Set(intervals.map { (($0 % 12) + 12) % 12 })
        let major = s.contains(4)
        let dim = s.contains(6) && !s.contains(7)
        let seventh: Int? = s.contains(11) ? 11 : (s.contains(10) ? 10 : nil)
        if dim { return "°" }
        if let sev = seventh {
            if major && sev == 11 { return "maj7" }
            if major && sev == 10 { return "7" }
            if !major && sev == 10 { return "m7" }
        }
        if major && s.contains(9) { return "6" }
        if major { return "" }
        return "m"
    }

    /// Name a chord from an absolute root pitch-class + intervals, transposed to the current key.
    static func chordName(rootPC: Int, intervals: [Int]) -> String {
        pcName(rootPC) + chordSuffix(intervals)
    }

    var rootName: String { MusicKey.pcNames[((root % 12) + 12) % 12] }
    var name: String { "\(rootName) \(mode.label)" }
    var scale: [Int] { mode.intervals }

    private var rootLetterIndex: Int {
        MusicKey.letters.firstIndex(of: String(rootName.prefix(1))) ?? 5
    }

    private static func accidental(_ semis: Int) -> String {
        switch ((semis % 12) + 12) % 12 {
        case 0: return ""
        case 1: return "♯"
        case 2: return "𝄪"
        case 11: return "♭"
        case 10: return "♭♭"
        default: return ""
        }
    }

    /// Correctly-spelled note letter (+accidental) for a scale degree.
    func noteName(degree: Int) -> String {
        let letterIdx = (rootLetterIndex + degree) % 7
        let letter = MusicKey.letters[letterIdx]
        let naturalPC = MusicKey.letterPC[letterIdx]
        let targetPC = ((root + scale[degree]) % 12 + 12) % 12
        return letter + MusicKey.accidental(targetPC - naturalPC)
    }

    /// Bare letter (no octave) for the pad grid.
    func letterOnly(degree: Int) -> String { noteName(degree: degree) }

    /// MIDI note for a scale degree at a given octave (C-based MIDI).
    func midi(degree: Int, octave: Int) -> Int {
        12 + 12 * octave + root + scale[degree]
    }

    /// MIDI for the chromatic offset above the tonic at an octave (for chord/bass roots).
    func midiForOffset(_ semis: Int, octave: Int) -> Int {
        12 + 12 * octave + root + semis
    }

    // MARK: Diatonic chords

    private func quality(third: Int, fifth: Int, seventh: Int?) -> (suffix: String, roman: (String) -> String) {
        let major = third == 4
        let dim = fifth == 6
        if let sev = seventh {
            if dim { return ("m7♭5", { $0.lowercased() + "ø" }) }
            if major && sev == 11 { return ("maj7", { $0 }) }
            if major && sev == 10 { return ("7", { $0 }) }
            if !major && sev == 10 { return ("m7", { $0.lowercased() }) }
        }
        if dim { return ("°", { $0.lowercased() + "°" }) }
        if major { return ("", { $0 }) }
        return ("m", { $0.lowercased() })
    }

    /// The 7 diatonic chords (triads + a 7th flavor) of the key.
    func diatonicChords(sevenths: Bool = true) -> [ChordSpec] {
        (0..<7).map { d in
            let rootOff = scale[d]
            let thirdOff = (scale[(d + 2) % 7] - scale[d] + 12) % 12
            let fifthOff = (scale[(d + 4) % 7] - scale[d] + 12) % 12
            let seventhOff = (scale[(d + 6) % 7] - scale[d] + 12) % 12
            let q = quality(third: thirdOff, fifth: fifthOff, seventh: sevenths ? seventhOff : nil)
            var ivals = [0, thirdOff, fifthOff]
            if sevenths { ivals.append(seventhOff) }
            // Roman numeral base from degree
            let baseRoman = ["I", "II", "III", "IV", "V", "VI", "VII"][d]
            return ChordSpec(
                degree: d,
                name: noteName(degree: d) + q.suffix,
                roman: q.roman(baseRoman),
                rootOffset: rootOff,
                intervals: ivals
            )
        }
    }

    /// The 7 diatonic chords ordered around the circle of fifths (adjacent = a fifth apart).
    func circleOfFifthsChords(sevenths: Bool = true) -> [ChordSpec] {
        let chords = diatonicChords(sevenths: sevenths)
        // order degrees by their root's position on the circle of fifths
        return chords.sorted { a, b in
            let pa = (a.rootOffset * 7) % 12
            let pb = (b.rootOffset * 7) % 12
            return pa < pb
        }
    }
}
