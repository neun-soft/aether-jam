import SwiftUI
import Combine

enum Route: Hashable {
    case track(UUID)        // role of the track decides which screen is shown
    case synthEditor(UUID)
    case mySounds
    case addInstrument      // sound list in "add as track" mode
}

@MainActor
final class AppStore: ObservableObject {
    // Catalog
    let bassLoops = MusicData.bassLoops
    let drumLoops = MusicData.drumLoops
    // Progression templates (built-in + user-saved). Each is an ordered list of degrees.
    @Published var chordTemplates: [ChordTemplate] = MusicData.chordTemplates

    // Project
    @Published var bpm: Int = 122
    @Published var trackName: String = "Midnight Drive"
    @Published var key: MusicKey = .default
    var keyName: String { key.name }

    // The sketch's tracks — a dynamic list. Seeded with one of each role.
    @Published var tracks: [Track] = []

    // Transport / global performance state
    @Published var recording = false
    @Published var octave = 3
    @Published var playing = false
    @Published var masterFilter: Double = 0.5     // bipolar DJ filter (0.5 = off)
    @Published var shimmerEnabled = true          // global shimmer-reverb on/off
    @Published var padActive: Set<Int> = []     // polyphonic: all currently-held pads (lead)
    private var padMidi: [Int: Int] = [:]        // pad id → the midi it triggered

    // Sound editing (the synth editor edits one specific track)
    @Published var editingTrackID: UUID? = nil
    @Published var synth = SynthParams()
    @Published var synthAdvanced = true
    @Published var presets = MusicData.defaultPresets
    @Published var activePreset = 0
    @Published var justSaved = false

    // Navigation
    @Published var hasStarted = false
    @Published var path: [Route] = []

    let audio = AudioEngine()
    private var saveTask: Task<Void, Never>?

    init() {
        loadPresets()
        loadChordTemplates()
        seedDefaultTracks()
        audio.configure(bpm: bpm)
        audio.setKeyRoot(key.root)
        // Nothing is selected at launch — each instrument is chosen explicitly by the user.
        // No audio is started on launch; the engine + transport spin up on Play / a lead pad.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-audiotest") {
            let r = audio.selfTestRMS(seconds: 10.0)
            NSLog("AETHER_SELFTEST %@", r)
        }
        applyDebugRoute()
        #endif
    }

    /// The starting four tracks — same as the original fixed stack.
    private func seedDefaultTracks() {
        let roles: [LayerKind] = [.bass, .chords, .drums, .lead]
        for role in roles { tracks.append(makeTrack(role: role, register: true)) }
    }

    /// Build a Track (and register its voice with the engine).
    private func makeTrack(role: LayerKind, register: Bool) -> Track {
        let count = tracks.filter { $0.role == role }.count
        let name = count == 0 ? role.title : "\(role.title) \(count + 1)"
        let t = Track(role: role, name: name)
        if register {
            audio.addTrack(id: t.id, role: role, params: t.params, eq: t.eq,
                           volume: t.volume, shimmer: t.shimmer, pitch: t.pitch)
        }
        return t
    }

    #if DEBUG
    /// Dev only: lets `xcrun simctl launch ... -route <name>` deep-link a screen for QA screenshots.
    private func applyDebugRoute() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-route"), i + 1 < args.count else { return }
        let name = args[i + 1]
        if name == "start" { return }
        hasStarted = true
        // Populate a good-looking demo state for marketing screenshots.
        if let b = firstTrack(.bass) { selectLoop(b.id, 2) }
        if let d = firstTrack(.drums) { selectLoop(d.id, 0) }
        if let c = firstTrack(.chords) { applyChordTemplate(c.id, chordTemplates[0]) }
        switch name {
        case "stack": path = []
        case "bass":   if let t = firstTrack(.bass)   { path = [.track(t.id)] }
        case "chords": if let t = firstTrack(.chords) { path = [.track(t.id)] }
        case "drums":  if let t = firstTrack(.drums)  { path = [.track(t.id)] }
        case "lead":   if let t = firstTrack(.lead)   { path = [.track(t.id)] }
        case "synth":  if let t = firstTrack(.lead)   { beginEditing(t.id); path = [.synthEditor(t.id)] }
        case "sounds": path = [.mySounds]
        default: break
        }
    }
    #endif

    // MARK: Track lookup

    func track(_ id: UUID) -> Track? { tracks.first { $0.id == id } }
    func firstTrack(_ role: LayerKind) -> Track? { tracks.first { $0.role == role } }
    private func index(_ id: UUID) -> Int? { tracks.firstIndex { $0.id == id } }
    private func mutate(_ id: UUID, _ f: (inout Track) -> Void) {
        if let i = index(id) { f(&tracks[i]) }
    }

    // MARK: Add / remove tracks

    @discardableResult
    func addTrack(role: LayerKind) -> UUID {
        let t = makeTrack(role: role, register: true)
        tracks.append(t)
        if role == .bass && !hasStarted { hasStarted = true }
        return t.id
    }

    /// Add a new track seeded from a saved/preset sound, and open it.
    func addTrackFromSound(_ preset: Preset) {
        let id = addTrack(role: preset.col)
        mutate(id) { $0.name = preset.name }
        if let p = preset.params {
            mutate(id) { $0.params = p }
            audio.setSynthParamsAll(id, params: p)
        }
        path = [.track(id)]
    }

    func removeTrack(_ id: UUID) {
        guard let t = track(id) else { return }
        audio.removeTrack(id: id)
        tracks.removeAll { $0.id == id }
        if editingTrackID == id { editingTrackID = nil }
        // Drop any navigation pointing at the removed track.
        path.removeAll { route in
            switch route { case .track(id), .synthEditor(id): return true; default: return false }
        }
        _ = t
    }

    // MARK: Derived (per track)

    /// A track is audible only if it has its selection and isn't muted (lead is performance-only).
    func isActive(_ t: Track) -> Bool {
        guard t.enabled else { return false }
        switch t.role {
        case .bass:   return t.loopIdx != nil
        case .chords: return chordsReady(t)
        case .drums:  return t.loopIdx != nil
        case .lead:   return false   // performance layer — no looping indicator
        }
    }

    func chordsReady(_ t: Track) -> Bool { !t.chordVoicings.isEmpty }

    func loopName(_ t: Track) -> String {
        switch t.role {
        case .bass:  return t.loopIdx.map { bassLoops[$0].name } ?? "Tap to choose a loop"
        case .drums: return t.loopIdx.map { drumLoops[$0].name } ?? "Tap to choose a kit"
        default:     return ""
        }
    }

    func chordsSubline(_ t: Track) -> String {
        if t.chordVoicings.isEmpty { return "Tap to build a progression" }
        return t.chordVoicings.map { voicingName($0) }.joined(separator: " · ")
    }

    /// The Stack sub-line shown under each track's name.
    func subline(_ t: Track) -> String {
        switch t.role {
        case .bass, .drums: return loopName(t)
        case .chords:       return chordsSubline(t)
        case .lead:         return "Aurora · tap to jam"
        }
    }

    // MARK: Actions — selection

    func startWithBass() {
        if let t = firstTrack(.bass) { path = [.track(t.id)] }
    }

    /// Bass loop or drum kit, depending on the track's role.
    func selectLoop(_ id: UUID, _ i: Int) {
        guard let t = track(id) else { return }
        mutate(id) { $0.loopIdx = i }
        if t.role == .drums {
            audio.setDrumKit(id, i)
            mutate(id) { $0.drumPattern = Self.defaultDrumLanes(i) }   // load that groove
            pushDrum(id)
        } else {
            audio.setBassLoop(id, i)
        }
        if t.role == .bass && !hasStarted { hasStarted = true }
    }

    // MARK: Drums — editable pattern

    static let drumLaneNames = ["KICK", "SNARE", "HAT", "CLAP"]

    /// A starting pattern for a groove preset: kick from the catalog + a sensible snare/hat.
    static func defaultDrumLanes(_ preset: Int) -> [[Bool]] {
        let kickRow = MusicData.drumPatterns[min(max(preset, 0), MusicData.drumPatterns.count - 1)]
        let kick = kickRow.map { $0 == 1 }
        var snare = Array(repeating: false, count: 16); snare[4] = true; snare[12] = true
        var hat = Array(repeating: false, count: 16); for i in stride(from: 0, to: 16, by: 2) { hat[i] = true }
        let clap = Array(repeating: false, count: 16)
        return [kick, snare, hat, clap]
    }

    func drumPatternOf(_ id: UUID) -> [[Bool]] { track(id)?.drumPattern ?? [] }

    func toggleDrumCell(_ id: UUID, lane: Int, step: Int) {
        mutate(id) { t in
            guard t.drumPattern.indices.contains(lane), t.drumPattern[lane].indices.contains(step) else { return }
            t.drumPattern[lane][step].toggle()
        }
        pushDrum(id)
    }

    func clearDrumPattern(_ id: UUID) {
        mutate(id) { $0.drumPattern = Array(repeating: Array(repeating: false, count: 16), count: 4) }
        pushDrum(id)
    }

    private func pushDrum(_ id: UUID) {
        guard let t = track(id) else { return }
        audio.setDrumPattern(id, t.drumPattern)
    }

    // MARK: Chords — voice-lane loop

    /// Visible scale-step rows in the editor (0 = tonic … up ~1.8 octaves).
    let chordRows = 0...12

    /// Scale-step index → semitones above the key tonic (handles octaves and negatives).
    private func scaleSemis(_ idx: Int) -> Int {
        let scale = key.scale, n = scale.count
        let oct = Int(floor(Double(idx) / Double(n)))
        let deg = ((idx % n) + n) % n
        return scale[deg] + 12 * oct
    }
    private func midiFor(_ idx: Int) -> Int { 48 + key.root + scaleSemis(idx) }

    /// The bare note letter for a scale-step index (for the dots).
    func noteLetter(_ idx: Int) -> String { key.letterOnly(degree: ((idx % 7) + 7) % 7) }

    /// Name a voicing (set of scale-step indices) as a chord in the current key.
    /// Picks the most chord-like root (not just the bass note), and adds a /slash bass
    /// for inversions — so a voice-led F voiced A-C-F reads "F/A", not "Am".
    func voicingName(_ voicing: [Int]) -> String {
        guard let lo = voicing.min() else { return "—" }
        let pcs = Array(Set(voicing.map { ((key.root + scaleSemis($0)) % 12 + 12) % 12 }))
        guard !pcs.isEmpty else { return "—" }
        let bassPC = ((key.root + scaleSemis(lo)) % 12 + 12) % 12
        func score(_ root: Int) -> Int {
            let iv = Set(pcs.map { (($0 - root) % 12 + 12) % 12 })
            var s = 0
            if iv.contains(4) || iv.contains(3) { s += 3 }                       // a third
            if iv.contains(7) { s += 3 } else if iv.contains(6) || iv.contains(8) { s += 1 }  // a fifth
            if iv.contains(10) || iv.contains(11) { s += 1 }                     // a seventh
            if iv.contains(2) || iv.contains(5) { s += 1 }                       // sus / add colour
            if iv.contains(1) { s -= 2 }                                         // harsh cluster
            return s
        }
        let rootPC = pcs.max(by: { score($0) < score($1) }) ?? bassPC
        let intervals = Array(Set(pcs.map { (($0 - rootPC) % 12 + 12) % 12 })).sorted()
        var name = MusicKey.chordName(rootPC: rootPC, intervals: intervals)
        if bassPC != rootPC { name += "/" + MusicKey.pcName(bassPC) }
        return name
    }

    // MARK: Chord / note editing

    func addChord(_ id: UUID) {
        // Copy the last chord (so the new one is a small move away), else a tonic triad.
        mutate(id) { $0.chordVoicings.append($0.chordVoicings.last ?? [0, 2, 4]) }
        pushChords(id)
    }
    func removeChord(_ id: UUID, at idx: Int) {
        mutate(id) { if $0.chordVoicings.indices.contains(idx) { $0.chordVoicings.remove(at: idx) } }
        pushChords(id)
    }
    func clearChords(_ id: UUID) { mutate(id) { $0.chordVoicings = [] }; pushChords(id) }

    private func clampRow(_ idx: Int) -> Int { min(chordRows.upperBound, max(chordRows.lowerBound, idx)) }

    /// Move a note within a chord by value (the dragged dot), keeping notes sorted & unique.
    func moveNote(_ id: UUID, chord ci: Int, from oldIdx: Int, to newIdx: Int) {
        let target = clampRow(newIdx)
        mutate(id) { t in
            guard t.chordVoicings.indices.contains(ci),
                  let pos = t.chordVoicings[ci].firstIndex(of: oldIdx) else { return }
            var v = t.chordVoicings[ci]
            v.remove(at: pos)
            if !v.contains(target) { v.append(target) }   // merge if it lands on a sibling
            t.chordVoicings[ci] = v.sorted()
        }
        pushChords(id)
    }
    func addNote(_ id: UUID, chord ci: Int, _ idx: Int) {
        let target = clampRow(idx)
        mutate(id) { t in
            guard t.chordVoicings.indices.contains(ci), !t.chordVoicings[ci].contains(target) else { return }
            t.chordVoicings[ci] = (t.chordVoicings[ci] + [target]).sorted()
        }
        pushChords(id)
    }
    func removeNote(_ id: UUID, chord ci: Int, value idx: Int) {
        mutate(id) { t in
            guard t.chordVoicings.indices.contains(ci), t.chordVoicings[ci].count > 1,
                  let pos = t.chordVoicings[ci].firstIndex(of: idx) else { return }
            t.chordVoicings[ci].remove(at: pos)
        }
        pushChords(id)
    }

    func setChordTiming(_ id: UUID, _ timing: ChordTiming) { mutate(id) { $0.timing = timing }; pushChords(id) }

    /// Load a template — each degree becomes a diatonic triad (stacked thirds) — then voice-lead it.
    func applyChordTemplate(_ id: UUID, _ template: ChordTemplate) {
        mutate(id) { $0.chordVoicings = template.degrees.map { [$0, $0 + 2, $0 + 4] } }
        autoSmooth(id)
    }

    /// Auto voice-lead: keep each chord's tones but re-octave them to sit closest to the
    /// previous chord, so the lines flatten out and the loop flows.
    func autoSmooth(_ id: UUID) {
        mutate(id) { t in
            guard !t.chordVoicings.isEmpty else { return }
            var prev = t.chordVoicings[0].sorted()
            t.chordVoicings[0] = prev
            for i in 1..<t.chordVoicings.count {
                let degrees = Set(t.chordVoicings[i].map { (($0 % 7) + 7) % 7 })
                var newV: [Int] = []
                for deg in degrees {
                    let placements = chordRows.filter { (($0 % 7) + 7) % 7 == deg }
                    // pick the octave placement closest to the nearest note of the previous chord
                    let best = placements.min(by: {
                        abs($0 - nearest(prev, $0)) < abs($1 - nearest(prev, $1))
                    }) ?? deg
                    newV.append(best)
                }
                newV = Array(Set(newV)).sorted()
                t.chordVoicings[i] = newV
                prev = newV
            }
        }
        pushChords(id)
    }
    private func nearest(_ set: [Int], _ x: Int) -> Int {
        set.min(by: { abs($0 - x) < abs($1 - x) }) ?? x
    }

    /// Resolve voicings to absolute MIDI and push to the engine.
    private func pushChords(_ id: UUID) {
        guard let t = track(id) else { return }
        let steps: [ChordStep] = t.chordVoicings.map { v in
            let sorted = v.sorted()
            return ChordStep(rootSemis: scaleSemis(sorted.first ?? 0), midis: sorted.map { midiFor($0) })
        }
        audio.setChordSequence(id, steps, timing: t.timing)
    }

    // MARK: Key

    func setKey(root: Int, mode: Mode) {
        key = MusicKey(root: ((root % 12) + 12) % 12, mode: mode)
        audio.setKeyRoot(key.root)
        // Re-voice chords and re-resolve bass lines in the new key (everything transposes).
        for t in tracks where t.role == .chords { pushChords(t.id) }
        for t in tracks where t.role == .bass { pushBass(t.id) }
    }
    func cycleKeyRoot(_ delta: Int) { setKey(root: key.root + delta, mode: key.mode) }
    func toggleMode() { setKey(root: key.root, mode: key.mode == .minor ? .major : .minor) }

    // MARK: Tempo

    func setBPM(_ value: Int) {
        bpm = min(150, max(90, value))
        audio.configure(bpm: bpm)
    }
    func nudgeBPM(_ delta: Int) { setBPM(bpm + delta) }

    // MARK: Record / transport

    func toggleRecord() {
        recording.toggle()
        if recording { audio.startEngine(); audio.startRecording() }
        else { audio.stopRecording() }
    }

    func setMasterFilter(_ v: Double) {
        masterFilter = min(1, max(0, v))
        audio.setMasterFilter(masterFilter)
    }

    func toggleShimmerMaster() {
        shimmerEnabled.toggle()
        audio.setShimmerMaster(shimmerEnabled)
    }

    func togglePlay() {
        playing.toggle()
        if playing { audio.startEngine(); audio.setTransport(true) }
        else { audio.setTransport(false) }
    }

    // MARK: Per-track mix

    func setEQ(_ id: UUID, _ v: Double) {
        let clamped = min(1, max(0, v))
        mutate(id) { $0.eq = clamped }
        audio.setFilter(id, value: clamped)
    }
    func eqValue(_ id: UUID) -> Double { track(id)?.eq ?? 0.5 }

    func setVolume(_ id: UUID, _ v: Double) {
        let clamped = min(1, max(0, v))
        mutate(id) { $0.volume = clamped }
        audio.setVolume(id, value: clamped)
    }
    func volumeOf(_ id: UUID) -> Double { track(id)?.volume ?? 0.8 }

    func toggleEnabled(_ id: UUID) {
        guard let t = track(id), t.role != .lead else { return }
        let now = !t.enabled
        mutate(id) { $0.enabled = now }
        audio.setEnabled(id, now)
    }
    func isEnabled(_ id: UUID) -> Bool { track(id)?.enabled ?? true }

    func isShimmerOn(_ id: UUID) -> Bool { track(id)?.shimmer ?? false }
    func toggleShimmer(_ id: UUID) {
        let now = !(track(id)?.shimmer ?? false)
        mutate(id) { $0.shimmer = now }
        audio.setShimmer(id, on: now)
    }

    // MARK: Bass note line (built on the scale row, like chords)

    /// Tap a note on the scale row: append it to the bass line (repeats allowed).
    func addBassNote(_ id: UUID, _ degree: Int) {
        mutate(id) { $0.bassNotes.append(degree) }
        pushBass(id)
    }
    func removeBassNote(_ id: UUID, at pos: Int) {
        mutate(id) { if $0.bassNotes.indices.contains(pos) { $0.bassNotes.remove(at: pos) } }
        pushBass(id)
    }
    func moveBassNote(_ id: UUID, from: Int, to: Int) {
        mutate(id) { t in
            guard t.bassNotes.indices.contains(from) else { return }
            let clamped = max(0, min(t.bassNotes.count - 1, to))
            let d = t.bassNotes.remove(at: from)
            t.bassNotes.insert(d, at: clamped)
        }
        pushBass(id)
    }
    func setBassTiming(_ id: UUID, _ timing: ChordTiming) {
        mutate(id) { $0.bassTiming = timing }
        pushBass(id)
    }
    func clearBassNotes(_ id: UUID) {
        mutate(id) { $0.bassNotes = [] }
        pushBass(id)
    }

    /// One-tap convenience: fill the bass line from the current chords progression's roots.
    func autofillBassFromChords(_ id: UUID) {
        guard let chordsTrack = tracks.first(where: { $0.role == .chords && !$0.chordVoicings.isEmpty }) else { return }
        // Each chord's root = the lowest note's scale degree.
        let roots = chordsTrack.chordVoicings.map { (((($0.min() ?? 0) % 7) + 7) % 7) }
        mutate(id) { $0.bassNotes = roots }
        pushBass(id)
    }

    /// The note name for a bass-line degree (0…6, or 7 = octave tonic) in the current key.
    func bassNoteName(_ degree: Int) -> String { key.letterOnly(degree: degree % 7) }

    /// Resolve a bass degree to semitones above the tonic (degree 7 = tonic up an octave).
    private func bassRootSemis(_ degree: Int) -> Int {
        let scale = key.scale
        let d = ((degree % 7) + 7) % 7
        let oct = degree / 7
        return scale[d] + 12 * oct
    }

    private func pushBass(_ id: UUID) {
        guard let t = track(id) else { return }
        let roots = t.bassNotes.map { bassRootSemis($0) }
        audio.setBassLine(id, roots, timing: t.bassTiming)
    }

    func pitchOf(_ id: UUID) -> Int { track(id)?.pitch ?? 0 }
    func pitchDown(_ id: UUID) {
        let v = max(-12, pitchOf(id) - 1)
        mutate(id) { $0.pitch = v }; audio.setPitch(id, v)
    }
    func pitchUp(_ id: UUID) {
        let v = min(12, pitchOf(id) + 1)
        mutate(id) { $0.pitch = v }; audio.setPitch(id, v)
    }

    // MARK: Lead octave + pads (polyphonic)

    func octDown() { octave = max(1, octave - 1) }
    func octUp() { octave = min(6, octave + 1) }

    func padDown(_ pad: Int, midi: Int, track id: UUID) {
        guard !padActive.contains(pad) else { return }
        padActive.insert(pad)
        padMidi[pad] = midi
        audio.startEngine()   // engine runs for live pads even when transport is stopped
        audio.noteOn(id, midi: midi)
    }
    func padUp(_ pad: Int, track id: UUID) {
        if let m = padMidi[pad] { audio.noteOff(id, midi: m); padMidi[pad] = nil }
        padActive.remove(pad)
    }

    // MARK: Synth editor (edits one track's sound)

    var editingRole: LayerKind { editingTrackID.flatMap { track($0)?.role } ?? .lead }
    var presetName: String { presets[activePreset].name }

    func beginEditing(_ id: UUID) {
        editingTrackID = id
        synth = track(id)?.params ?? SynthParams()
    }

    func setSynth(_ key: String, _ v: Double) {
        let clamped = min(1, max(0, v))
        synth[key] = clamped
        guard let id = editingTrackID else { return }
        mutate(id) { $0.params = synth }
        audio.setSynthParam(id, key: key, value: clamped)
    }

    /// Switch the editor to the first track of a role (the editor's role tabs).
    func editRole(_ role: LayerKind) {
        if let t = firstTrack(role) { beginEditing(t.id) }
    }

    func toggleAdvanced() { synthAdvanced.toggle() }

    func selectPreset(_ i: Int) {
        activePreset = i
        guard let p = presets[i].params, let id = editingTrackID else { return }
        synth = p
        mutate(id) { $0.params = p }
        audio.setSynthParamsAll(id, params: p)
    }

    func saveSound() {
        let role = editingRole
        let snapshot = synth
        let n = presets.filter { $0.col == role && $0.params != nil }.count + 1
        let newPreset = Preset(
            name: "\(role.title.capitalized) \(n)",
            tag: role.title,
            col: role,
            desc: describeSound(snapshot),
            params: snapshot
        )
        presets.insert(newPreset, at: 0)
        activePreset = 0
        persistPresets()
        justSaved = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run { self?.justSaved = false }
        }
    }

    func duplicatePreset(_ i: Int) {
        guard presets.indices.contains(i) else { return }
        var copy = presets[i]
        copy.id = UUID()
        copy.name += " copy"
        if copy.params == nil { copy.params = synth }
        presets.insert(copy, at: i + 1)
        activePreset = i + 1
        persistPresets()
    }

    func deletePreset(_ i: Int) {
        guard presets.indices.contains(i), presets[i].params != nil else { return } // only user sounds
        presets.remove(at: i)
        activePreset = min(activePreset, presets.count - 1)
        persistPresets()
    }

    private func describeSound(_ s: SynthParams) -> String {
        let shimmer = Int(s.fxShim * 100)
        let wt = s.oWave < 0.25 ? "Sine" : (s.oWave < 0.5 ? "Tri" : (s.oWave < 0.75 ? "Saw" : "Square"))
        return "\(wt) · Shimmer \(shimmer) · Cut \(Int(s.fCut * 100))"
    }

    // MARK: Preset persistence (user sounds survive launches)

    private let presetsKey = "aether.userPresets.v1"

    private func persistPresets() {
        let userPresets = presets.filter { $0.params != nil }
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: presetsKey),
              let saved = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = saved + MusicData.defaultPresets
    }

    // MARK: User progression persistence

    private let chordTemplatesKey = "aether.userChordTemplates.v1"

    private func persistChordTemplates() {
        let userTemplates = chordTemplates.filter { $0.isUser }
        if let data = try? JSONEncoder().encode(userTemplates) {
            UserDefaults.standard.set(data, forKey: chordTemplatesKey)
        }
    }

    private func loadChordTemplates() {
        guard let data = UserDefaults.standard.data(forKey: chordTemplatesKey),
              let saved = try? JSONDecoder().decode([ChordTemplate].self, from: data) else { return }
        chordTemplates = MusicData.chordTemplates + saved
    }
}
