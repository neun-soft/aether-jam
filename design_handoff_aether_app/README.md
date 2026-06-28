# Handoff: Aether — Mobile Melodic-House Jam App

## Overview
Aether is an iOS app for jamming progressive / melodic house from a phone. The core idea: the simplest possible "Vital-style" wavetable synth, wrapped in a loop-based jam workflow. The user builds a track as a **stack of layers** (Bass → Chords → Drums → Lead), each layer started from a curated default loop and tunable with friendly controls. A single shared **synth engine** powers Bass, Chords, and Lead; custom sounds can be saved to a **global "My Sounds" library** and reused on any layer. The Lead is performed live on a scale-locked **pad grid** so anyone can jam without a keyboard.

This package documents the **"Aether Stacks"** design direction (the chosen direction). A second exploration file (`Aether Jam.dc.html`) is included for reference only — it shows three earlier visual directions for the hero screen and a first-pass synth editor; **do not implement it**.

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes showing the intended look, layout, and interactions. They are **not production code to copy directly**. They were authored as "Design Components" (a streaming HTML prototyping format); the markup is plain HTML + inline styles and the logic is a small JS class, but you should treat them as a visual + behavioral spec, not a source tree.

Your task is to **recreate these designs in the target codebase's environment**. For an iOS app the natural target is **SwiftUI** (or UIKit), using the platform's native gesture, audio (AVAudioEngine / AudioKit), and animation systems. If you are building a cross-platform shell instead (React Native, Flutter), recreate the same screens with that stack's idioms. Use the HTML only to read exact measurements, colors, type, copy, and interaction behavior.

## Fidelity
**High-fidelity.** Colors, typography, spacing, component shapes, and interaction behavior are final and intended to be matched closely. The only deliberately "placeholder" elements are the audio content itself (loop names, preset names, waveform/EQ shapes are illustrative) and the iOS status bar. Recreate the UI to match the mocks, sourcing real audio/DSP from the app's engine.

---

## Design Tokens

### Color
| Token | Hex | Use |
|---|---|---|
| `bg/gradient-top` | `#12151f` | Screen background top of vertical gradient |
| `bg/gradient-bottom` | `#0a0c12` | Screen background bottom (`linear-gradient(168deg, #12151f 0%, #0a0c12 100%)`) |
| `surface/panel` | `#161a24` | Primary card / row / tile fill |
| `surface/panel-alt` | `#13161e` | Secondary inset panel fill |
| `surface/subtle` | `rgba(255,255,255,0.025)` | Synth section panels |
| `hairline` | `rgba(255,255,255,0.05–0.09)` | Borders / dividers |
| `text/primary` | `#eef1f7` | Titles, active values |
| `text/secondary` | `#cfd4dd` | Sub-labels |
| `text/muted` | `#9aa0ad` | Inactive labels |
| `text/dim` | `#6c7689` | Mono captions |
| `text/faint` | `#5a606e` / `#4a505e` | Meta, "coming soon" |
| **accent/bass** | `#5b9dff` (rgb 91,157,255) | Bass layer |
| **accent/chords** | `#c79bff` (rgb 199,155,255) | Chords layer |
| **accent/drums** | `#7fd6a0` (rgb 127,214,160) | Drums layer |
| **accent/lead** | `#e8c07d` (rgb 232,192,125) | Lead layer + synth/preset accents |
| `accent/rec` | `#e8553a` | Record dot |
| `accent/neutral` | `#8b94a6` (rgb 139,148,166) | Unassigned preset chips |

**Accent system:** each of the four layers owns one accent color, used consistently for its tile left-border, dot, EQ knob arc, waveform/EQ stroke, swatch selection ring, and the equalizer "playing" bars. Tinted fills use the accent at `0.08–0.18` alpha; selection borders use the solid accent.

### Typography
- **Display / UI:** `Space Grotesk` (400/500/600/700). Titles 20–26px/600; section/row titles 15–17px/600; body 14–16px.
- **Mono / data:** `JetBrains Mono` (400/500/600). Captions 10–13px, letter-spacing 0.5–2px, frequently uppercased. Used for BPM, key, loop meta, knob labels, tags, section headers.
- Negative letter-spacing (−0.2 to −0.4px) on large titles; positive tracking (1–4px) on mono captions.

### Radius
- Screen frame: `46px` · Cards/rows/panels: `15–18px` · Pills/swatches: `9–14px` · Pads: `13px` · Small controls: `6–11px`.

### Shadow / Glow
- Frame: `0 30px 80px rgba(0,0,0,0.55)` (mockup only — not in-app).
- Accent glow on active waveforms/dots: `drop-shadow(0 0 4–5px <accent>55)` / `box-shadow: 0 0 8–24px <accent>`.
- Active pad: `box-shadow: 0 0 24px rgba(232,192,125,0.6)` + `transform: scale(0.96)`.

### Spacing
- Screen horizontal padding: 16–26px. Card inner padding: 13–18px. Gaps between stacked cards: 10–12px. Grid pad gaps: 9px.

### Device frame
- Design canvas is per-screen **393 × 852** (iPhone 15/16 logical points). All screens are full-height flex columns: fixed header → flexible body → fixed footer.

---

## Screens / Views

### 1. Start (`data-screen-label="Start"`)
- **Purpose:** First run / new sketch. Enforces a bass-first workflow.
- **Layout:** Header (`NEW JAM` eyebrow, "Untitled Sketch" title, "122 BPM · A MINOR"). Then a vertical stack of 4 layer rows. Footer hint.
- **Components:**
  - **Bass row (active/prompt):** tinted bass fill `rgba(91,157,255,0.09)`, 1.5px bass border + 3px left border, **pulsing border animation** (`promptpulse`, 2.2s). Icon tile `+`, title "BASS", sub "Tap to choose a loop", chevron `›`.
  - **Chords / Drums / Lead rows (locked):** `#13161e`, faint accent left-border, `opacity:0.5`. Sub-labels "Add bass first" (chords, drums) and "The part you jam" (lead).
  - Footer copy: "Start with the bass — it's the foundation everything sits on."
- **Behavior:** Only Bass is tappable; it routes to **Bass · Inside**. Other rows unlock once a bass loop is chosen.

### 2. The Stack — hub (`data-screen-label="Stack"`)
- **Purpose:** Main arrangement view. Shows all four layers; transport at bottom.
- **Layout:** Header (track name + "{bpm} BPM · A MINOR", `+` button). Flexible column of 4 layer rows. Footer transport bar (top hairline border).
- **Components:**
  - **Layer row** (`min-height:80px`, `#161a24`, 3px accent left-border): a **colored rounded tile (34×34)** on the left that toggles mute (tinted+accent border when on, neutral when off); title (BASS/CHORDS/DRUMS/LEAD); mono sub-line showing the current loop/selection (Chords shows the chord names joined by " · "; Lead shows "Aurora · tap to jam"); animated **EQ bars** (3 bars, `eq` keyframe) shown when the layer is on; chevron `›`. Muted rows drop to `opacity:0.45`.
  - **Transport:** left = "{bpm} BPM"; center = circular **play/pause** button (56px — filled white when paused showing a play triangle, dark/translucent when playing showing a pause glyph); right = **REC** dot + label.
- **Behavior:** Tap a layer tile → toggle mute (Lead is always "performance", never shows the on-bars). Tap a row body → open that layer's detail screen. Play button toggles global playback. `+` adds a layer.

### 3. Lead · Jam (`data-screen-label="Lead Jam"`)
- **Purpose:** Live performance surface for the lead. **No piano keyboard — a scale-locked pad grid** (deliberate: easier to jam on a phone).
- **Layout:** Header (back `‹`, "LEAD" in lead accent, "AURORA PLUCK · A MINOR", right cluster = "⚙ SOUND" pill + animated EQ bars). Control row (scale chip, octave − / OCT n / +). **4×4 pad grid** (flex:1). Footer **filter-morph ribbon**.
- **Components:**
  - **Scale chip:** "SCALE · A MIN" tinted lead. **Octave stepper:** − / "OCT {octave}" / + (range 1–6, default 3).
  - **Pad (16):** rounded 13px tile. Notes are drawn from the A-minor scale, laid out so the **bottom-left is lowest** and pitch rises left→right, bottom→top (`rank = (3-row)*4 + col`). Root notes (A) get a faint lead tint + border; others are `#161a24`. Each pad shows the **note letter** (17px/600) and **note+octave** (mono 9px). **Active (pressed)** pad fills solid lead `#e8c07d`, dark text, glow + `scale(0.96)`.
  - **Filter-morph ribbon:** 40px tall track `#161a24`; drag horizontally → fill (lead gradient) grows and a 3px glowing playhead follows; label shows the resulting cutoff (e.g. "1.2k"). This is a one-finger expressive macro.
- **Behavior:** `pointerdown` on a pad sets it active (triggers note); `pointerup`/`pointerleave` releases. Ribbon is a drag control mapping x-position 0→1 to filter cutoff. "⚙ SOUND" routes to the Synth Editor for the Lead.

### 4. Bass · Inside (`data-screen-label="Bass Inside"`)
- **Purpose:** Pick/swap the bass loop, transpose pitch, sweep an EQ filter. (Per-note editing is explicitly future scope.)
- **Layout:** Header (back, "BASS" accent, current loop name). "NOW PLAYING" waveform card. "SWAP LOOP" horizontal swatch strip. "Pitch" stepper row. EQ filter card (curve + big knob). Footer: **⚙ EDIT SOUND** button (bass-tinted) + "notes soon" hint.
- **Components:**
  - **Now-playing card:** tinted bass panel, "NOW PLAYING" / "1 BAR · LOOP", a **filled waveform** polygon (bass stroke/fill) that changes shape per selected loop.
  - **Loop swatches (horizontal scroll):** each `min-width:108px`, name + mono meta. Selected = tinted fill + solid accent border + bright text. Loops: *Sub Roller (OFFBEAT), Reese Pulse (GLIDE), Deep Saw (WARM), 808 Glide (TRAP-ish), Pluck Bass (TIGHT)*.
  - **Pitch stepper:** − / "{±n st}" / + (semitones, range −12…+12, default 0), value in bass accent.
  - **EQ filter card:** an EQ response **curve** (SVG polyline, redraws live) above a **circular arc knob** (88px) — drag vertically to move cutoff; center shows Hz label ("CUTOFF"). Helper text "DRAG TO SWEEP THE FILTER".
  - **Footer:** "⚙ EDIT SOUND" → Synth Editor (bass). "notes soon" = future note-editing.
- **Behavior:** Tapping a swatch swaps the loop (updates waveform + the Stack sub-line). Knob drag updates the cutoff curve in real time.

### 5. Chords · Inside (`data-screen-label="Chords Inside"`)
- **Purpose:** Choose a chord **progression** (not individual loops) + EQ.
- **Layout:** Header (back, "CHORDS" accent, "{progName} · A MINOR"). "PROGRESSION" list (flex:1). EQ row (small knob + small curve). Footer **⚙ EDIT SOUND** (chords-tinted).
- **Components:**
  - **Progression card (4):** title + mood tag (mono), and a row of 4 **chord chips**. Selected card = chords-tinted fill + accent border, chips brighten. Progressions (key A minor):
    - *Emotive (WARM):* Am7 · Fmaj7 · Cmaj7 · G6
    - *Nightfall (DARK):* Am · C · G · Em
    - *Drifting (DREAMY):* Dm7 · Am7 · B♭ · F
    - *Sunrise (UPLIFT):* Fmaj7 · Am7 · Dm7 · G
  - **EQ row:** 80px arc knob (chords accent) + compact EQ curve.
- **Behavior:** Tap a progression to select (updates Stack sub-line). Knob drags cutoff. EDIT SOUND → Synth Editor (chords).

### 6. Drums · Inside (`data-screen-label="Drums Inside"`)
- **Purpose:** Swap drum loop/kit, preview the 16-step pattern, EQ.
- **Layout:** Header (back, "DRUMS" accent, loop name). "PATTERN · 16 STEP" card (16-cell step grid). "SWAP KIT / LOOP" swatch strip. EQ filter card (curve + big knob). 
- **Components:**
  - **Step grid:** 16 cells, accent-filled + glow on hit steps, faint on rests; beat-1-of-4 rests slightly brighter. Pattern changes per selected loop.
  - **Loop swatches:** *Deep 4x4 (CLASSIC), Garage Skip (SWUNG), Breakbeat (BROKEN), Minimal (SPARSE), Peak Time (DRIVING)*.
  - **EQ filter card:** same pattern as Bass, drums accent. (Drums has no Edit Sound — it is sample-based, not the synth engine.)
- **Behavior:** Swatch tap swaps kit → repaints step pattern + waveform context. Knob drags cutoff.

### 7. Synth Editor — shared engine (`data-screen-label="Synth Editor"`)
- **Purpose:** The single wavetable synth that powers **Bass, Chords, and Lead**. Friendly macros on top; full sound design optional below; save to global library.
- **Layout:** Header (back, **preset name** in current layer accent, "SAME ENGINE · EDITING {LAYER}", A/B pill). **Layer tabs** (BASS / CHORDS / LEAD). Scrollable body: **MACROS** panel → "SOUND DESIGN" row with **ADVANCED** toggle → (when advanced) Oscillator, Filter+Envelope, Shimmer Reverb panels. Fixed footer **SAVE TO MY SOUNDS** button.
- **Components:**
  - **Layer tabs:** segmented; selected tab uses that layer's accent (fill+border+text). Switching tabs re-themes the whole editor accent and shows that layer's sound. Demonstrates "one engine, used everywhere."
  - **Macros (4 large 70px arc knobs):** BRIGHT, MOVEMENT, SPACE, DRIVE — each a circular **arc gauge** (270° sweep, −135°→+135°), accent arc over a faint track, % value in center. These are the "easy controls / defaults."
  - **ADVANCED toggle:** mono pill; when on reveals detail panels (default ON in the mock so the full engine is visible).
  - **Oscillator · Wavetable:** live **waveform polyline** that morphs with WT POS; voices/detune readout ("7 VOICES · 24c"); two 42px arc knobs (WT POS, UNISON).
  - **Filter:** EQ-style **response curve** (green) + CUT / RES 40px arc knobs.
  - **Envelope:** **ADSR** filled curve (amber) + A/D/S/R 32px arc knobs.
  - **Shimmer Reverb:** lavender→cyan gradient panel, "✦ SHIMMER REVERB", three 46px arc knobs SIZE / SHIMMER / MIX.
  - **Save button:** solid accent; on tap flips to "✓ SAVED TO MY SOUNDS" (tinted) for ~2.2s.
- **Behavior:** All knobs are **vertical-drag** arc controls (drag up = increase; ~170–180px of travel = full range, 0→1 clamped). Curves/waveform redraw live from knob values. Save writes the current sound to the global library (see screen 8).

### 8. My Sounds — global library (`data-screen-label="My Sounds"`)
- **Purpose:** Browse, save, and reuse sounds across any layer.
- **Layout:** Header (back, "My Sounds", "GLOBAL LIBRARY · REUSE ON ANY LAYER"). **Save banner** (accent-themed, shows current sound + source layer + SAVE). "SAVED · {LAYER} ⌄" filter label. Scrollable **library list**.
- **Components:**
  - **Save banner:** lead-tinted card, `+` tile, "Save current sound" / "{presetName} · from {LAYER}", SAVE label.
  - **Library row:** 38px rounded accent dot, name (15px/600), mono description, and a **tag chip** (LEAD/BASS/CHORDS/PAD in accent, or neutral "—" when unassigned). Selected row = tinted fill + accent border + white name. Presets:
    - *Aurora Pluck* — LEAD — "Bright WT · Shimmer 55 · Soft env"
    - *Deep Sub* — BASS — "Sine + sub · LP 180Hz · Tight"
    - *Glass Keys* — CHORDS — "Bell WT · Long release · Wide"
    - *Velvet Saw* — PAD — "Warm saw · Shimmer 80 · Slow"
- **Behavior:** Tap a row to load/select that sound (highlights). Save banner / SAVE writes the editor's current sound here. Tags indicate which layer a sound was made for, but any sound can be loaded onto any layer.

---

## Interactions & Behavior (cross-cutting)

- **Arc knobs (synth + EQ):** pointer-capture on `pointerdown`; on `pointermove` compute `value = startValue + (startY − currentY) / travel` (travel ≈170–180px), clamp 0–1. Render as an SVG arc path sweeping 270° (`−135°` start). EQ knobs map value→cutoff Hz via `60 · 2^(value·7.5)`, formatted `<1000 → "N"`, `≥1000 → "N.Nk"`.
- **Filter ribbon (Lead):** pointer-capture drag; `value = (clientX − left) / width`, clamp 0–1 → cutoff.
- **Pads:** press = active note (visual depress + glow), release on up/leave. Notes derive from the selected scale + octave; layout ascends left→right, bottom→top.
- **Loop / progression / preset selection:** single-select per layer; selection drives accent fill + border and propagates a summary string back to the Stack hub.
- **Mute toggles:** per-layer on the Stack; muted = dim + no EQ bars.
- **EQ "playing" bars:** 3-bar equalizer, `@keyframes eq { 0%,100% { transform: scaleY(0.3) } 50% { transform: scaleY(1) } }`, ~0.6–0.7s, staggered delays (0 / 0.2 / 0.4s), `transform-origin: bottom`.
- **Start prompt pulse:** `@keyframes promptpulse` animating the bass row border color, 2.2s ease-in-out.
- **Save confirmation:** transient 2.2s state swap on the save control.

## State Management
Per the prototype's logic, the app state is roughly:
- `loopSel: { bass, drums }` — selected loop index per sample-based layer.
- `prog` — selected chord-progression index.
- `eq: { bass, drums, chords, lead }` — per-layer filter cutoff (0–1).
- `pitch` — bass transpose in semitones (−12…+12).
- `octave` — lead pad octave (1–6).
- `layerOn: { bass, chords, drums }` — mute flags.
- `padActive` — id of currently pressed lead pad (or null).
- `playing` — global transport.
- `synthLayer: 'bass'|'chords'|'lead'` — which layer the shared Synth Editor is editing (drives accent theme).
- `synthAdvanced` — advanced panels visible.
- `synth: { bright, move, space, drive, oWave, oUni, fCut, fRes, eA, eD, eS, eR, fxSize, fxShim, fxMix }` — all 0–1.
- `presets[]` + `activePreset` — the global My Sounds library and current selection.
- `justSaved` — transient save-confirmation flag.

**Data fetching / audio:** the prototype mocks all audio. In production you need: a loop library (audio files + tempo/key metadata, time-stretched to project BPM), the wavetable synth engine (osc → filter → ADSR → shimmer reverb send), a clock/transport syncing all layers, and persistence for projects + the global sound library.

## Assets
- **Fonts:** Space Grotesk + JetBrains Mono (Google Fonts). Swap for bundled equivalents on iOS.
- **No raster images or icon files** — all glyphs are typographic/CSS (chevrons, +, −, ✦, ⚙, play/pause/triangles via borders, waveforms/curves via inline SVG). Replace with SF Symbols or a vector set in-app.
- **Audio (not included):** loops, drum kits, wavetables, reverb impulse — supplied by the engine.

## Files
- `Aether Stacks.dc.html` — **the design to implement.** All 8 screens, laid out on a pannable canvas (status bar + nav are mock chrome). Read inline styles for exact values and the `<script>` logic block for interaction math (arc paths, EQ/ADSR curve builders, pad note mapping).
- `Aether Jam.dc.html` — **reference only** (earlier hero-screen explorations + first synth editor). Do not build.
- `support.js` — prototype runtime; **ignore**, not part of the app.
