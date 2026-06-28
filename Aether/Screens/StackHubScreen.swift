import SwiftUI

struct StackHubScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.trackName).ui(21, .semibold).tracking(-0.2)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(store.bpm) BPM · \(store.tracks.count) tracks")
                        .mono(12).tracking(0.5)
                        .foregroundStyle(Theme.textDim)
                }
                Spacer(minLength: 4)
                keyControl
                Button { store.path.append(.addInstrument) } label: {
                    Text("♪+").font(.system(size: 14)).foregroundStyle(Theme.neutral)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.rPill))
                        .overlay(RoundedRectangle(cornerRadius: Theme.rPill).stroke(Theme.hairline(0.09)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Rows
            ScrollView(showsIndicators: false) {
                VStack(spacing: 11) {
                    ForEach(store.tracks) { track in
                        layerRow(track)
                    }
                    addTrackButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)

            transport
        }
        .screen()
        .confirmationDialog("Add a track", isPresented: $showAddSheet, titleVisibility: .visible) {
            ForEach([LayerKind.bass, .chords, .drums, .lead], id: \.self) { role in
                Button(role.title.capitalized) {
                    let id = store.addTrack(role: role)
                    store.path.append(.track(id))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every track is the same synth — the layout adapts to the type you pick.")
        }
    }

    private var addTrackButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05))
                    Text("+").font(.system(size: 22, weight: .light)).foregroundStyle(Theme.neutral)
                }
                .frame(width: 34, height: 34)
                Text("ADD TRACK").ui(15, .semibold).tracking(0.5).foregroundStyle(Theme.textMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: Theme.rRow))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rRow)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .foregroundStyle(Theme.hairline(0.14))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    // The shimmer "river" — a shared reverb send the track dips into. Lavender = shimmer.
    private func shimmerChip(_ track: Track) -> some View {
        let on = store.isShimmerOn(track.id)
        let shimmer = Color(hex: "c79bff")
        return Text("✦").font(.system(size: 13))
            .foregroundStyle(on ? shimmer : Theme.textFaint)
            .frame(width: 30, height: 30)
            .background(on ? shimmer.opacity(0.16) : Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(on ? shimmer.opacity(0.6) : Theme.hairline(0.08)))
            .shadow(color: on ? shimmer.opacity(0.5) : .clear, radius: on ? 6 : 0)
            .contentShape(Rectangle())
            .onTapGesture { store.toggleShimmer(track.id) }
    }

    private func hasSelection(_ track: Track) -> Bool {
        switch track.role {
        case .bass:   return track.loopIdx != nil
        case .chords: return store.chordsReady(track)
        case .drums:  return track.loopIdx != nil
        case .lead:   return true
        }
    }

    private func layerRow(_ track: Track) -> some View {
        let layer = track.role
        let isLead = layer == .lead
        let selected = hasSelection(track)
        let active = store.isActive(track)          // selected + un-muted → shows EQ bars
        let dimmed = selected && !isLead && !active // chosen but muted → dim
        return Button { store.path.append(.track(track.id)) } label: {
            VStack(spacing: 9) {
                HStack(spacing: 14) {
                    // Mute tile (only meaningful once a loop is chosen)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(active ? layer.tint(0.18) : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(active ? layer.accent : Theme.hairline(0.08)))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                        .onTapGesture { if !isLead && selected { store.toggleEnabled(track.id) } }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name).ui(16, .semibold).tracking(0.4)
                            .foregroundStyle(Theme.textPrimary)
                        Text(store.subline(track)).mono(12)
                            .foregroundStyle(selected ? (isLead ? layer.accent : layer.tint(0.9)) : Theme.textFaint)
                            .lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 4)
                    if active { EQBars(accent: layer.accent, barHeight: 18).frame(width: 24) }
                    shimmerChip(track)
                    Text("›").font(.system(size: 20)).foregroundStyle(Theme.textFaint)
                }
                // Slim per-track volume fader + filter knob (live performance controls)
                if selected {
                    HStack(spacing: 12) {
                        VolumeFader(value: store.volumeOf(track.id), accent: layer.accent, height: 4) {
                            store.setVolume(track.id, $0)
                        }
                        ZStack {
                            ArcKnob(value: store.eqValue(track.id), accent: layer.accent, size: 30, lineWidth: 4,
                                    trackColor: layer.tint(0.16), travel: 170,
                                    onChange: { _ in }) {
                                Text("FLT").mono(6).foregroundStyle(Theme.textDim)
                            }
                            .allowsHitTesting(false)
                            // Independent touch → drag several track filters at once like a DJ.
                            MultiTouchKnobSurface(onChange: { store.setEQ(track.id, $0) },
                                                  currentValue: { store.eqValue(track.id) })
                        }
                        .frame(width: 34, height: 34)
                    }
                    .padding(.leading, 48).padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 80)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.rRow))
            .overlay(RoundedRectangle(cornerRadius: Theme.rRow).stroke(Theme.hairline(0.05)))
            .overlay(alignment: .leading) {
                layer.accent.frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .opacity(dimmed ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if store.tracks.count > 1 {
                Button(role: .destructive) { store.removeTrack(track.id) } label: {
                    Label("Remove track", systemImage: "trash")
                }
            }
        }
    }

    // Inline key control — change root (‹ ›) and tap the centre to flip major/minor.
    private var keyControl: some View {
        HStack(spacing: 2) {
            Button { store.cycleKeyRoot(-1) } label: {
                Text("‹").font(.system(size: 15)).foregroundStyle(Theme.textMuted).frame(width: 20, height: 32)
            }.buttonStyle(.plain)
            Button { store.toggleMode() } label: {
                VStack(spacing: 0) {
                    Text(store.key.rootName).ui(14, .semibold).foregroundStyle(Theme.textPrimary)
                    Text(store.key.mode == .minor ? "min" : "maj").mono(8).foregroundStyle(LayerKind.chords.accent)
                }
                .frame(minWidth: 26)
            }.buttonStyle(.plain)
            Button { store.cycleKeyRoot(1) } label: {
                Text("›").font(.system(size: 15)).foregroundStyle(Theme.textMuted).frame(width: 20, height: 32)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.rPill))
        .overlay(RoundedRectangle(cornerRadius: Theme.rPill).stroke(Theme.hairline(0.09)))
    }

    // Master DJ filter — bipolar horizontal sweep with a centre detent.
    private var masterFilterBar: some View {
        let v = store.masterFilter
        let isLP = v < 0.47, isHP = v > 0.53
        let col = isLP ? LayerKind.bass.accent : (isHP ? LayerKind.lead.accent : Theme.textDim)
        let shimmer = Color(hex: "c79bff")
        return VStack(spacing: 3) {
            HStack(spacing: 8) {
                Text("FILTER").mono(9).tracking(1.5).foregroundStyle(Theme.textDim)
                Spacer()
                // Global shimmer-reverb on/off
                Text("✦").font(.system(size: 12))
                    .foregroundStyle(store.shimmerEnabled ? shimmer : Theme.textFaint)
                    .frame(width: 26, height: 22)
                    .background(store.shimmerEnabled ? shimmer.opacity(0.16) : Color.white.opacity(0.03), in: Capsule())
                    .overlay(Capsule().stroke(store.shimmerEnabled ? shimmer.opacity(0.6) : Theme.hairline(0.1)))
                    .contentShape(Capsule())
                    .onTapGesture { store.toggleShimmerMaster() }
                Text(isLP ? "LOW-PASS" : (isHP ? "HIGH-PASS" : "OFF")).mono(9).foregroundStyle(col)
                    .frame(width: 64, alignment: .trailing)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let hx = CGFloat(v) * w
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 5)
                        .frame(maxHeight: .infinity)
                    Rectangle().fill(Theme.hairline(0.25)).frame(width: 1, height: 12)
                        .position(x: w / 2, y: geo.size.height / 2)
                    // fill from centre to handle
                    Rectangle().fill(col.opacity(0.5))
                        .frame(width: abs(hx - w / 2), height: 5)
                        .position(x: (hx + w / 2) / 2, y: geo.size.height / 2)
                    Circle().fill(col).frame(width: 18, height: 18)
                        .shadow(color: col.opacity(0.6), radius: 5)
                        .position(x: hx, y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in store.setMasterFilter(g.location.x / w) }
                        .onEnded { g in
                            let nv = g.location.x / w
                            if abs(nv - 0.5) < 0.05 { store.setMasterFilter(0.5) }   // snap to centre
                        }
                )
            }
            .frame(height: 22)
        }
        .padding(.horizontal, 22).padding(.top, 6)
    }

    private var transport: some View {
        VStack(spacing: 0) {
            masterFilterBar
            HStack {
                tempoControl.frame(width: 96, alignment: .leading)
                Spacer()
                Button { store.togglePlay() } label: { playButton }.buttonStyle(.plain)
                Spacer()
                recButton.frame(width: 96, alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 26)
        }
        .overlay(alignment: .top) { Theme.hairline(0.06).frame(height: 1) }
        .padding(.top, 8)
    }

    // Tap = +2 BPM (wraps), vertical drag = scrub. Range 90–150.
    @State private var dragBPMStart: Int? = nil
    private var tempoControl: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text("\(store.bpm)").mono(15, .semibold).foregroundColor(Theme.textPrimary)
                Text("BPM").mono(11).foregroundColor(Theme.neutral)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                    .foregroundStyle(Theme.textDim)
            }
            Text("TEMPO").mono(8).tracking(1).foregroundStyle(Theme.textFaint)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.hairline(0.08)))
        .contentShape(Rectangle())
        .onTapGesture {
            store.setBPM(store.bpm >= 150 ? 90 : store.bpm + 2)
        }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { g in
                    if dragBPMStart == nil { dragBPMStart = store.bpm }
                    let delta = Int((-g.translation.height / 4).rounded())
                    store.setBPM((dragBPMStart ?? store.bpm) + delta)
                }
                .onEnded { _ in dragBPMStart = nil }
        )
    }

    private var recButton: some View {
        Button { store.toggleRecord() } label: {
            HStack(spacing: 7) {
                if store.recording {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.rec).frame(width: 12, height: 12)
                        .shadow(color: Theme.rec.opacity(0.7), radius: 7)
                } else {
                    Circle().fill(Theme.rec).frame(width: 13, height: 13)
                        .shadow(color: Theme.rec.opacity(0.55), radius: 6)
                }
                Text(store.recording ? "REC •" : "REC").mono(13, store.recording ? .semibold : .regular)
                    .foregroundStyle(store.recording ? Theme.rec : Theme.neutral)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }

    private var playButton: some View {
        ZStack {
            Circle()
                .fill(store.playing ? Color.white.opacity(0.06) : Color.white.opacity(0.9))
                .overlay(Circle().stroke(Theme.hairline(0.12)))
            if store.playing {
                // pause glyph
                HStack(spacing: 4) {
                    Capsule().fill(Theme.textPrimary).frame(width: 4, height: 16)
                    Capsule().fill(Theme.textPrimary).frame(width: 4, height: 16)
                }
            } else {
                // play triangle
                Triangle().fill(Theme.bgTop)
                    .frame(width: 16, height: 20)
                    .offset(x: 2)
            }
        }
        .frame(width: 56, height: 56)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
