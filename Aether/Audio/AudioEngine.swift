import Foundation

/// Public surface the UI/state talks to. DSP implementation lives in SynthCore.
final class AudioEngine {
    private let core = SynthCore()

    func configure(bpm: Int) { core.configure(bpm: bpm) }
    #if DEBUG
    func selfTestRMS(seconds: Double) -> String { core.selfTest(seconds: seconds) }
    #endif
    func startEngine() { core.startEngine() }
    func setTransport(_ on: Bool) { core.setTransport(on) }
    func start() { core.startEngine(); core.setTransport(true) }
    func stop() { core.setTransport(false) }

    // Track lifecycle
    func addTrack(id: UUID, role: LayerKind, params: SynthParams, eq: Double,
                  volume: Double, shimmer: Bool, pitch: Int) {
        core.addTrack(id: id, role: role, params: params, eq: eq, volume: volume, shimmer: shimmer, pitch: pitch)
    }
    func removeTrack(id: UUID) { core.removeTrack(id: id) }

    // Per-track selection
    func setBassLoop(_ id: UUID, _ idx: Int?) { core.setBassLoop(id, idx) }
    func setDrumKit(_ id: UUID, _ idx: Int?) { core.setDrumKit(id, idx) }
    func setDrumPattern(_ id: UUID, _ lanes: [[Bool]]) { core.setDrumPattern(id, lanes) }
    func setChordSequence(_ id: UUID, _ steps: [ChordStep], timing: ChordTiming) { core.setChordSequence(id, steps, timing: timing) }
    func setKeyRoot(_ pc: Int) { core.setKeyRoot(pc) }
    func setMasterFilter(_ v: Double) { core.setMasterFilter(v) }
    func setShimmerMaster(_ on: Bool) { core.setShimmerMaster(on) }
    func setBassLine(_ id: UUID, _ roots: [Int], timing: ChordTiming) { core.setBassLine(id, roots, timing: timing) }

    // Per-track mix
    func setEnabled(_ id: UUID, _ on: Bool) { core.setEnabled(id, on) }
    func setShimmer(_ id: UUID, on: Bool) { core.setShimmer(id, on) }
    func setVolume(_ id: UUID, value: Double) { core.setVolume(id, value) }
    func setFilter(_ id: UUID, value: Double) { core.setFilter(id, value) }
    func setPitch(_ id: UUID, _ semitones: Int) { core.setPitch(id, semitones) }

    // Live notes (lead pads)
    func noteOn(_ id: UUID, midi: Int) { core.noteOn(id, midi) }
    func noteOff(_ id: UUID, midi: Int) { core.noteOff(id, midi) }

    // Recording
    func startRecording() { core.startRecording() }
    func stopRecording() { core.stopRecording() }

    // Synth params
    func setSynthParam(_ id: UUID, key: String, value: Double) { core.setParam(id, key, value) }
    func setSynthParamsAll(_ id: UUID, params: SynthParams) { core.setParams(id, params) }
    func snapshot(_ id: UUID) -> SynthParams { core.snapshot(id) }
    func loadPreset(_ preset: Preset, onTrack id: UUID) { core.loadPreset(preset, id) }
}
