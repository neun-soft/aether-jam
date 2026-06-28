import Foundation
import AVFoundation

// Console-only diagnostics (never writes to the user-visible Documents folder).
func adbg(_ msg: String) {
    #if DEBUG
    NSLog("AETHER_AUDIO %@", msg)
    #endif
}

// MARK: - Lightweight spinlock for audio/UI parameter handoff

final class Spinlock {
    private var lock = os_unfair_lock()
    @inline(__always) func sync<T>(_ body: () -> T) -> T {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return body()
    }
}

// MARK: - Per-track instrument (shared wavetable engine)

final class Instrument {
    let layer: LayerKind
    let sampleRate: Double
    private var voices: [Voice]
    private var filter: SVFilter
    private var rr = 0
    private var lfoPhase = 0.0

    var params = SynthParams()
    var eq: Double = 0.5
    var enabled = true
    var shimmerOn = false      // attached to the shared shimmer "river"?
    var userVolume = 0.85      // 0…1 fader
    var pitchOffset = 0
    var gain: Double

    init(layer: LayerKind, sampleRate: Double, polyphony: Int, gain: Double) {
        self.layer = layer
        self.sampleRate = sampleRate
        self.gain = gain
        voices = (0..<polyphony).map { _ in Voice(sampleRate: sampleRate) }
        filter = SVFilter(sampleRate: sampleRate)
    }

    private func cutoffHz() -> Double {
        // The detail-screen EQ knob is the dominant filter sweep; the editor CUT and BRIGHT
        // macro nudge it. Maps to a wide musical range (~80 Hz … ~12 kHz).
        let v = clamp01(0.05 + 0.62 * eq + 0.22 * params.fCut + 0.14 * params.bright)
        return 70.0 * pow(2.0, v * 7.6)
    }

    func noteOn(_ midi: Int, velocity: Double = 0.9) {
        let m = midi + pitchOffset
        let voices7 = min(5, Int((1 + params.oUni * 4).rounded()))   // cap unison for CPU safety
        let detune = params.oUni * 40
        // map ADSR (seconds) from normalized params
        let a = 0.002 + params.eA * 1.6
        let h = params.eH * 1.5          // up to 1.5s held at peak
        let d = 0.01 + params.eD * 1.2
        let s = params.eS
        let r = 0.02 + params.eR * 2.0
        // pick a free or oldest voice
        var v = voices.first { !$0.active }
        if v == nil { v = voices[rr % voices.count]; rr += 1 }
        v?.noteOn(midi: m, voices: voices7, detuneCents: detune, a: a, h: h, d: d, s: s, r: r, vel: velocity)
    }

    func noteOff(_ midi: Int) {
        let m = midi + pitchOffset
        for v in voices where v.active && v.midi == m { v.noteOff() }
    }

    func allOff() { for v in voices { v.noteOff() } }

    /// Returns (dry, reverbSend).
    @inline(__always) func renderSample() -> (Double, Double) {
        guard enabled else { return (0, 0) }
        // movement LFO modulates wavetable morph
        lfoPhase += (0.3 + params.move * 5.0) / sampleRate
        if lfoPhase >= 1 { lfoPhase -= 1 }
        let morph = clamp01(params.oWave + sin(lfoPhase * 2 * .pi) * 0.25 * params.move)

        var sum = 0.0
        for v in voices { sum += v.render(morph: morph) }
        // filter
        filter.set(cutoff: cutoffHz(), resonance: params.fRes)
        var x = filter.process(sum)
        x = saturate(x, drive: params.drive)
        x *= gain * userVolume
        // Send to the shared shimmer only when this track is attached to the river.
        let send = shimmerOn ? x * 0.6 : 0
        return (x, send)
    }
}

// MARK: - One track's audio voice (melodic Instrument OR a DrumSynth)

final class TrackVoice {
    let id: UUID
    var role: LayerKind
    let inst: Instrument?        // bass / chords / lead
    let drum: DrumSynth?         // drums
    let drumFilter: SVFilter

    // Drum mix lives here (melodic mix lives on `inst`).
    var drumEq: Double = 0.62
    var drumVolume: Double = 0.85
    var drumEnabled = true
    var drumShimmerOn = false
    var drumLanes: [[Bool]] = []     // editable [kick, snare, hat, clap] × 16 steps

    // Sequencer selection (set under lock from UI thread)
    var loopIdx: Int? = nil          // bass loop OR drum kit
    // Bass note line: resolved root offsets (semitones above the key tonic) + loop timing.
    var bassRoots: [Int] = []
    var bassTiming: ChordTiming = .fit
    // Chords: a resolved progression + how its loop time is split.
    var chordSteps: [ChordStep] = []
    var chordTiming: ChordTiming = .fit
    var chordIdx: Int = -1           // currently-sounding chord index (-1 = none yet)
    var activeRootSemis: Int = 0     // root of the sounding chord (the bass follows it)
    var currentChordMidis: [Int] = []

    init(id: UUID, role: LayerKind, sampleRate: Double) {
        self.id = id
        self.role = role
        self.drumFilter = SVFilter(sampleRate: sampleRate)
        switch role {
        case .bass:   inst = Instrument(layer: .bass,   sampleRate: sampleRate, polyphony: 3, gain: 0.28); drum = nil
        case .chords: inst = Instrument(layer: .chords, sampleRate: sampleRate, polyphony: 6, gain: 0.16); drum = nil
        case .lead:   inst = Instrument(layer: .lead,   sampleRate: sampleRate, polyphony: 5, gain: 0.26); drum = nil
        case .drums:  inst = nil; drum = DrumSynth(sampleRate: sampleRate)
        }
    }
}

// MARK: - SynthCore: AVAudioEngine + sequencer + reverb

final class SynthCore {
    private let engine = AVAudioEngine()
    private var srcNode: AVAudioSourceNode!
    private let sampleRate: Double

    private let reverb: ShimmerReverb
    private let limiter: Limiter
    private let masterFilter: SVFilter
    private var masterAmt: Double = 0.5         // target (0.5 = off · <0.5 low-pass · >0.5 high-pass)
    private var masterAmtSmooth: Double = 0.5   // per-sample smoothed value (no click on sweep)
    private var masterSmoothCoef: Double = 0
    private var shimmerMaster = true            // global shimmer-reverb on/off

    // Dynamic set of tracks. Mutated under `lock`; the audio thread reads a snapshot.
    private var voices: [TrackVoice] = []
    private var renderVoices: [TrackVoice] = []   // audio-thread working copy

    // sequencer
    private let lock = Spinlock()
    private var playing = false
    private var bpm = 122.0
    private var sampleCounter = 0.0
    private var step = -1
    private var totalSteps = 0        // monotonic 16th-note counter (drives chord loops)
    private var duckEnv = 0.0          // smoothed sidechain pump amount (0…1)
    private var duckTarget = 0.0       // pump target (set to 1 at the kick, decays)
    private let swing = 0.14           // groove: delays the off-16ths

    private var keyRoot = 9            // pitch class of the key tonic (default A)

    // pending UI note events (lead pads)
    private struct NoteEvent { let id: UUID; let midi: Int; let on: Bool }
    private var pending: [NoteEvent] = []

    // diagnostics
    private(set) var renderCount = 0
    private(set) var lastPeak: Double = 0
    private(set) var maxPeak: Double = 0

    // We render the synth at a fixed, known rate and let AVAudioEngine convert to whatever
    // the hardware uses. This avoids reading the output format before the audio session is
    // configured (which on a real device gives a wrong/stale format → garbage then silence).
    private let renderFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!

    init() {
        // Remove any stale dev log left in Documents by earlier builds (now user-visible via Files).
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("aether_audio.log"))

        SynthCore.configureSession()       // set the playback category BEFORE touching formats
        sampleRate = renderFormat.sampleRate
        reverb = ShimmerReverb(sampleRate: sampleRate)
        limiter = Limiter(sampleRate: sampleRate, ceiling: 0.9)
        masterFilter = SVFilter(sampleRate: sampleRate)
        masterSmoothCoef = 1.0 - exp(-1.0 / (0.008 * sampleRate))   // ~8ms glide

        setupNode()

        // The engine reconfigures on route/session changes (e.g. when the session activates,
        // headphones plug in). Reconnect + restart so audio keeps flowing.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            adbg("configChange isRunning=\(self.engine.isRunning) renders=\(self.renderCount)")
            self.reconnectAndStart()
        }
    }

    private func reconnectAndStart() {
        engine.connect(srcNode, to: engine.mainMixerNode, format: renderFormat)
        if !engine.isRunning {
            engine.prepare()
            do { try engine.start() } catch { adbg("restart failed: \(error)") }
        }
    }

    private func setupNode() {
        srcNode = AVAudioSourceNode(format: renderFormat) { [unowned self] _, _, frameCount, abl -> OSStatus in
            self.render(frameCount: Int(frameCount), abl: abl)
            return noErr
        }
        engine.attach(srcNode)
        // Connect through the engine's mixer; the engine inserts a sample-rate converter
        // between our fixed render format and the hardware output automatically.
        engine.connect(srcNode, to: engine.mainMixerNode, format: renderFormat)
        engine.mainMixerNode.outputVolume = 0.9
    }

    // MARK: Track lifecycle

    private func voice(_ id: UUID) -> TrackVoice? { lock.sync { voices.first { $0.id == id } } }

    func addTrack(id: UUID, role: LayerKind, params: SynthParams, eq: Double,
                  volume: Double, shimmer: Bool, pitch: Int) {
        let v = TrackVoice(id: id, role: role, sampleRate: sampleRate)
        if let inst = v.inst {
            inst.params = params; inst.eq = eq; inst.userVolume = volume
            inst.shimmerOn = shimmer; inst.pitchOffset = pitch
        } else {
            v.drumEq = eq; v.drumVolume = volume; v.drumShimmerOn = shimmer
        }
        lock.sync { voices.append(v) }
    }

    func removeTrack(id: UUID) {
        lock.sync {
            if let i = voices.firstIndex(where: { $0.id == id }) {
                voices[i].inst?.allOff()
                voices.remove(at: i)
            }
        }
    }

    // MARK: Transport / config

    func configure(bpm: Int) { self.bpm = Double(bpm) }

    /// Start the audio engine (idempotent). Does NOT start the sequencer — the app stays
    /// silent until something actually plays a note.
    func startEngine() {
        guard !engine.isRunning else { return }
        SynthCore.configureSession()
        engine.prepare()
        do { try engine.start() } catch { adbg("engine start failed: \(error)") }
    }

    /// Start/stop the sequencer (the looping bass/chords/drums groove).
    func setTransport(_ on: Bool) {
        if on { startEngine() }
        playing = on
        if !on {
            lock.sync {
                for v in voices { v.inst?.allOff(); v.currentChordMidis = []; v.chordIdx = -1 }
            }
        }
    }

    // MARK: Recording (captures the master output to a file)

    private var recordFile: AVAudioFile?
    private(set) var isRecording = false

    func startRecording() {
        guard !isRecording else { return }
        startEngine()
        let mixer = engine.mainMixerNode
        let fmt = mixer.outputFormat(forBus: 0)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stamp = Int(Date().timeIntervalSince1970)
        let url = dir.appendingPathComponent("aether-jam-\(stamp).m4a")
        // Compressed AAC so takes are ~4–5 MB, not ~50 MB, and play everywhere.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: fmt.sampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
        do {
            recordFile = try AVAudioFile(forWriting: url, settings: settings)
        } catch {
            adbg("record file create failed: \(error)")
            return
        }
        mixer.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buffer, _ in
            try? self?.recordFile?.write(from: buffer)
        }
        isRecording = true
        adbg("recording started: \(url.lastPathComponent)")
    }

    func stopRecording() {
        guard isRecording else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        recordFile = nil   // closes the file
        isRecording = false
        adbg("recording stopped")
    }

    private static func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    // MARK: Mutators (from UI/main thread)

    func setBassLoop(_ id: UUID, _ idx: Int?) { lock.sync { voices.first { $0.id == id }?.loopIdx = idx } }
    func setDrumKit(_ id: UUID, _ idx: Int?) {
        lock.sync {
            guard let v = voices.first(where: { $0.id == id }) else { return }
            v.loopIdx = idx
            if let i = idx { v.drum?.setKit(i) }
        }
    }
    func setDrumPattern(_ id: UUID, _ lanes: [[Bool]]) {
        lock.sync { voices.first(where: { $0.id == id })?.drumLanes = lanes }
    }
    /// Update a chords track's progression + timing. Edits reconcile the *currently sounding*
    /// chord in place — notes that stay keep ringing, only changed notes are released/added — so
    /// moving a dot never restarts the loop or re-attacks the chord.
    func setChordSequence(_ id: UUID, _ steps: [ChordStep], timing: ChordTiming) {
        lock.sync {
            guard let v = voices.first(where: { $0.id == id }) else { return }
            v.chordSteps = steps
            v.chordTiming = timing
            guard let inst = v.inst else { return }

            if steps.isEmpty {
                for m in v.currentChordMidis { inst.noteOff(m) }
                v.currentChordMidis = []
                v.chordIdx = -1
                v.activeRootSemis = 0
                return
            }
            if v.chordIdx >= steps.count { v.chordIdx = steps.count - 1 }
            // Reconcile the sounding chord to its new voicing without re-striking held notes.
            if v.chordIdx >= 0 {
                let target = steps[v.chordIdx].midis
                for m in v.currentChordMidis where !target.contains(m) { inst.noteOff(m) }
                if inst.enabled {
                    for m in target where !v.currentChordMidis.contains(m) { inst.noteOn(m, velocity: 0.42) }
                }
                v.currentChordMidis = target
                v.activeRootSemis = steps[v.chordIdx].rootSemis
            }
        }
    }

    func setKeyRoot(_ pc: Int) { lock.sync { keyRoot = ((pc % 12) + 12) % 12 } }

    /// Master DJ filter: 0.5 = off, toward 0 closes a low-pass, toward 1 opens a high-pass.
    func setMasterFilter(_ v: Double) { masterAmt = min(1, max(0, v)) }
    func setShimmerMaster(_ on: Bool) { shimmerMaster = on }

    /// Set a bass track's note line (resolved root offsets) + timing. Empty = play the tonic.
    func setBassLine(_ id: UUID, _ roots: [Int], timing: ChordTiming) {
        lock.sync {
            guard let v = voices.first(where: { $0.id == id }) else { return }
            v.bassRoots = roots
            v.bassTiming = timing
        }
    }

    func setEnabled(_ id: UUID, _ on: Bool) {
        guard let v = voice(id) else { return }
        if let inst = v.inst { inst.enabled = on; if !on { lock.sync { inst.allOff() } } }
        else { v.drumEnabled = on }
    }

    func setShimmer(_ id: UUID, _ on: Bool) {
        guard let v = voice(id) else { return }
        if let inst = v.inst { inst.shimmerOn = on } else { v.drumShimmerOn = on }
    }

    func setVolume(_ id: UUID, _ value: Double) {
        guard let v = voice(id) else { return }
        if let inst = v.inst { inst.userVolume = value } else { v.drumVolume = value }
    }

    func setFilter(_ id: UUID, _ value: Double) {
        guard let v = voice(id) else { return }
        if let inst = v.inst { inst.eq = value } else { v.drumEq = value }
    }

    func setPitch(_ id: UUID, _ semitones: Int) { voice(id)?.inst?.pitchOffset = semitones }

    func noteOn(_ id: UUID, _ midi: Int) { lock.sync { pending.append(NoteEvent(id: id, midi: midi, on: true)) } }
    func noteOff(_ id: UUID, _ midi: Int) { lock.sync { pending.append(NoteEvent(id: id, midi: midi, on: false)) } }

    func setParam(_ id: UUID, _ key: String, _ value: Double) { voice(id)?.inst?.params[key] = value }
    func setParams(_ id: UUID, _ p: SynthParams) { voice(id)?.inst?.params = p }
    func snapshot(_ id: UUID) -> SynthParams { voice(id)?.inst?.params ?? SynthParams() }
    func loadPreset(_ preset: Preset, _ id: UUID) {
        if let p = preset.params { voice(id)?.inst?.params = p }
    }

    // MARK: Offline self-test (deterministic proof the graph produces audio)

    #if DEBUG
    /// Renders `seconds` offline with the sequencer + a sustained lead note running, and
    /// reports the PEAK per 1-second window.
    func selfTest(seconds: Double) -> String {
        let outFmt = engine.outputNode.outputFormat(forBus: 0)
        let cap: AVAudioFrameCount = 4096
        guard (try? engine.enableManualRenderingMode(.offline, format: outFmt, maximumFrameCount: cap)) != nil,
              let buf = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: cap)
        else { return "selftest: manual rendering unavailable" }

        // Fresh deterministic set of tracks.
        lock.sync { voices.removeAll() }
        let b = UUID(), c = UUID(), d = UUID(), l = UUID()
        addTrack(id: b, role: .bass,   params: Track.defaultParams(.bass),   eq: 0.5,  volume: 0.85, shimmer: true, pitch: 0)
        addTrack(id: c, role: .chords, params: Track.defaultParams(.chords), eq: 0.7,  volume: 0.8,  shimmer: true, pitch: 0)
        addTrack(id: d, role: .drums,  params: Track.defaultParams(.drums),  eq: 0.62, volume: 0.85, shimmer: true, pitch: 0)
        addTrack(id: l, role: .lead,   params: Track.defaultParams(.lead),   eq: 0.6,  volume: 0.82, shimmer: true, pitch: 0)
        configure(bpm: 122)
        playing = true
        setBassLoop(b, 0); setDrumKit(d, 0)
        setBassLine(b, [0, 7, 3, 5], timing: .fit)   // exercise the bass note-line path
        let kick = [true,false,false,false, true,false,false,false, true,false,false,false, true,false,true,false]
        let hat  = (0..<16).map { $0 % 2 == 0 }
        let none = Array(repeating: false, count: 16)
        setDrumPattern(d, [kick, none, hat, none])   // exercise the drum-lane path
        // Am → F → C → G in A minor, mid register.
        let seq: [ChordStep] = [
            ChordStep(rootSemis: 0,  midis: [57, 60, 64]),
            ChordStep(rootSemis: 8,  midis: [53, 57, 60]),
            ChordStep(rootSemis: 3,  midis: [48, 52, 55]),
            ChordStep(rootSemis: 10, midis: [55, 59, 62]),
        ]
        setChordSequence(c, seq, timing: .fit)
        noteOn(l, 69)
        do { try engine.start() } catch { return "selftest: engine start failed \(error)" }

        var windowPeaks: [Double] = []
        var winPeak = 0.0, winN = 0, hasNaN = false
        let perWindow = Int(sampleRate)
        var n = 0
        let target = Int(seconds * sampleRate)
        while n < target {
            let frames = AVAudioFrameCount(min(Int(cap), target - n))
            guard (try? engine.renderOffline(frames, to: buf)) != nil,
                  let ch = buf.floatChannelData?[0] else { break }
            for i in 0..<Int(frames) {
                let v = Double(ch[i])
                if !v.isFinite { hasNaN = true; continue }
                winPeak = max(winPeak, abs(v))
                winN += 1
                if winN >= perWindow { windowPeaks.append(winPeak); winPeak = 0; winN = 0 }
            }
            n += Int(frames)
        }
        if winN > 0 { windowPeaks.append(winPeak) }
        engine.stop()

        let peaks = windowPeaks.map { String(format: "%.3f", $0) }.joined(separator: " ")
        let maxP = windowPeaks.max() ?? 0
        let climbing = windowPeaks.count >= 3 && (windowPeaks.last ?? 0) > (windowPeaks[1] + 0.05)
        return "selftest peaks/s=[\(peaks)] max=\(String(format: "%.3f", maxP)) hasNaN=\(hasNaN) climbing=\(climbing)"
    }
    #endif

    // MARK: Render (audio thread)

    private func render(frameCount: Int, abl: UnsafeMutablePointer<AudioBufferList>) {
        // drain UI note events + snapshot the track list
        renderVoices = lock.sync {
            for e in pending {
                if let inst = voices.first(where: { $0.id == e.id })?.inst {
                    if e.on { inst.noteOn(e.midi) } else { inst.noteOff(e.midi) }
                }
            }
            pending.removeAll(keepingCapacity: true)
            return voices
        }

        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        let samplesPerStep = sampleRate * 60.0 / bpm / 4.0   // 16th notes
        renderCount += 1
        var framePeak = 0.0

        // per-drum-track filter sweep
        for v in renderVoices where v.drum != nil {
            v.drumFilter.set(cutoff: 60.0 * pow(2.0, clamp01(v.drumEq) * 7.5), resonance: 0.1)
        }

        // sidechain pump: release scaled to tempo (~0.7 of a beat); attack smoothed over
        // ~2.5 ms so the gain never steps instantly (an instant step = the click/pop).
        let duckCoef = exp(-1.0 / ((60.0 / bpm) * 0.7 * sampleRate))
        let duckAttack = 1.0 - exp(-1.0 / (0.0025 * sampleRate))

        for frame in 0..<frameCount {
            if playing {
                sampleCounter -= 1
                if sampleCounter <= 0 {
                    advanceStep()
                    // swing: lengthen the interval after even 16ths so the off-16ths land late
                    sampleCounter += samplesPerStep * (step % 2 == 0 ? (1 + swing) : (1 - swing))
                }
            }

            // smoothed sidechain envelope (no instant jumps → no clicks)
            duckTarget *= duckCoef
            duckEnv += (duckTarget - duckEnv) * duckAttack

            // duck depths per role (bass & pads pump hardest)
            let dB = 1 - 0.72 * duckEnv
            let dC = 1 - 0.55 * duckEnv
            let dL = 1 - 0.20 * duckEnv

            var mono = 0.0
            var send = 0.0
            for v in renderVoices {
                if let inst = v.inst {
                    let r = inst.renderSample()
                    let duck = v.role == .bass ? dB : (v.role == .chords ? dC : dL)
                    mono += r.0 * duck; send += r.1 * duck
                } else if let drum = v.drum, v.drumEnabled {
                    let dr = v.drumFilter.process(drum.render()) * v.drumVolume
                    mono += dr * 0.7
                    if v.drumShimmerOn { send += dr * 0.4 }
                }
            }

            let wet = reverb.process(send * 0.35)
            var out = mono * 0.85 + (shimmerMaster ? wet * 0.3 : 0)   // shimmer (global on/off)
            if !out.isFinite { out = 0 }          // never propagate NaN/Inf
            // Master DJ filter — bipolar sweep. Smooth the knob and blend to dry through a
            // centre dead-zone so the low-pass↔high-pass flip is silent (no click).
            masterAmtSmooth += (masterAmt - masterAmtSmooth) * masterSmoothCoef
            let a = masterAmtSmooth
            let dist = abs(a - 0.5)
            let dead = 0.06
            let mfWet = max(0.0, min(1.0, (dist - dead) / (0.5 - dead)))
            let filtered: Double
            if a <= 0.5 {
                masterFilter.set(cutoff: 110.0 * pow(20000.0 / 110.0, a / 0.5), resonance: 0.22)
                filtered = masterFilter.processLPHP(out).lp     // always run → state stays warm
            } else {
                masterFilter.set(cutoff: 20.0 * pow(6500.0 / 20.0, (a - 0.5) / 0.5), resonance: 0.22)
                filtered = masterFilter.processLPHP(out).hp
            }
            out = out * (1 - mfWet) + filtered * mfWet
            out = limiter.process(out)            // brick-wall master limiter (≤ 0.9)
            framePeak = max(framePeak, abs(out))

            let fout = Float(out)
            for buffer in buffers {
                guard let raw = buffer.mData else { continue }   // defensive: skip null buffer
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                if frame < count { raw.assumingMemoryBound(to: Float.self)[frame] = fout }
            }
        }
        lastPeak = framePeak
        if framePeak > maxPeak { maxPeak = framePeak }
    }

    private func advanceStep() {
        step = (step + 1) % 16
        totalSteps += 1
        if step % 4 == 0 { duckTarget = 1.0 }    // sidechain pump on every quarter (4/4 feel)

        // Chords: each chords track advances its own progression (per-step granularity so
        // FIT mode can change chords mid-bar).
        for v in renderVoices where v.role == .chords { updateChordVoice(v) }

        // Bass: each bass track plays its own note line; the chosen loop supplies the rhythm
        // and octave/fifth movement on top of the current note's root.
        for v in renderVoices where v.role == .bass {
            guard let inst = v.inst, inst.enabled, let loop = v.loopIdx,
                  let off = SeqData.bassOffset(loop: loop, step: step) else { continue }
            let root: Int
            if v.bassRoots.isEmpty {
                root = 0                                 // no line picked → hold the tonic
            } else {
                let idx = loopIndex(count: v.bassRoots.count, timing: v.bassTiming)
                root = v.bassRoots[idx]
            }
            inst.allOff()
            inst.noteOn(24 + keyRoot + root + off, velocity: 0.8)
        }

        // drums — each drum track plays its own editable pattern (kick/snare/hat/clap lanes).
        for v in renderVoices where v.role == .drums {
            guard v.drumEnabled, let drum = v.drum, !v.drumLanes.isEmpty else { continue }
            let L = v.drumLanes
            if L.count > 0, step < L[0].count, L[0][step] { drum.triggerKick() }
            if L.count > 1, step < L[1].count, L[1][step] { drum.triggerSnare() }
            if L.count > 2, step < L[2].count, L[2][step] { drum.triggerHat(open: step == 14) }
            if L.count > 3, step < L[3].count, L[3][step] { drum.triggerClap() }
        }
    }

    /// Decide which chord of a progression should sound at the current step, and (re)strike it
    /// only when it changes. FIT splits a fixed 4-bar loop evenly; FREE gives one bar per chord.
    private func updateChordVoice(_ v: TrackVoice) {
        guard let inst = v.inst else { return }
        let n = v.chordSteps.count
        guard n > 0, inst.enabled else {
            if !v.currentChordMidis.isEmpty { for m in v.currentChordMidis { inst.noteOff(m) }; v.currentChordMidis = [] }
            v.chordIdx = -1
            v.activeRootSemis = 0
            return
        }
        let idx = loopIndex(count: n, timing: v.chordTiming)
        guard idx != v.chordIdx else { v.activeRootSemis = v.chordSteps[idx].rootSemis; return }
        v.chordIdx = idx
        let chord = v.chordSteps[idx]
        for m in v.currentChordMidis { inst.noteOff(m) }
        v.currentChordMidis = chord.midis
        v.activeRootSemis = chord.rootSemis
        for m in chord.midis { inst.noteOn(m, velocity: 0.42) }
    }

    /// Which step of an N-element looped line is active now.
    /// FIT splits a fixed 4-bar (64-step) loop evenly; FREE gives one bar (16 steps) per step.
    private func loopIndex(count n: Int, timing: ChordTiming) -> Int {
        guard n > 0 else { return 0 }
        switch timing {
        case .free: return (totalSteps / 16) % n
        case .fit:
            let pos = ((totalSteps % 64) + 64) % 64
            return min(n - 1, pos * n / 64)
        }
    }
}

// MARK: - Sequencer note data

enum SeqData {
    // Per-loop 16-step bass patterns as INTERVALS (semitones) from the current chord root,
    // nil = rest. The actual pitch is chordRoot + interval, so the bass moves with the chords.
    // 0 = root · 7 = fifth · 12 = octave · 10 = ♭7 · 3 = ♭3 · 5 = fourth.
    static let bassPatterns: [[Int?]] = [
        // Sub Roller (OFFBEAT) — root pulse with octave pops
        [0,nil,nil,0,  nil,nil,12,nil, 0,nil,nil,0,  nil,12,nil,nil],
        // Reese Pulse (GLIDE) — root→fifth movement
        [0,0,nil,nil,  7,nil,nil,nil,  0,0,nil,nil,  10,nil,12,nil],
        // Deep Saw (WARM) — slow root, ♭7 and fourth color
        [0,nil,nil,nil, 0,nil,nil,10,  5,nil,nil,nil, 7,nil,nil,nil],
        // 808 Glide (TRAP-ish) — syncopated with octave slides
        [0,nil,nil,12, nil,nil,nil,0,  nil,nil,7,nil, nil,nil,10,nil],
        // Pluck Bass (TIGHT) — busy 16ths, root/octave/fifth
        [0,nil,12,nil, 0,nil,7,nil,   0,nil,12,nil, 7,nil,10,nil],
    ]
    static func bassOffset(loop: Int, step: Int) -> Int? {
        bassPatterns[min(loop, bassPatterns.count - 1)][step]
    }
}
