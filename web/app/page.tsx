import Image from "next/image";
import { Nav, Footer, APP_STORE_URL } from "./components";

export default function Home() {
  return (
    <>
      <Nav />

      {/* Hero */}
      <header className="container hero">
        <div>
          <span className="eyebrow">Wavetable synth · loop jams</span>
          <h1>
            Jam <span className="grad-text">melodic house</span> from your phone.
          </h1>
          <p className="lede">
            Build a track as a stack of layers — bass, chords, drums and a live
            lead — each shaped by one Vital-style wavetable synth. No timeline,
            no clutter. Just pick a sound and play.
          </p>
          <div className="cta-row">
            <a href={APP_STORE_URL} className="btn btn-primary">
              Download on the App Store
            </a>
            <a href="#features" className="btn btn-ghost">
              See how it works
            </a>
          </div>
          <div className="hero-meta">
            iPhone · iOS 17+ · No account, no sign-up, nothing collected
          </div>
        </div>
        <div className="phone-wrap">
          <div className="phone">
            <Image
              src="/shots/stack.png"
              alt="Aether's stack view with Bass, Chords, Drums and Lead layers"
              width={1284}
              height={2778}
              style={{ height: "auto" }}
              priority
            />
          </div>
        </div>
      </header>

      {/* Layer chips */}
      <section className="section" style={{ paddingTop: 40, paddingBottom: 40 }}>
        <div className="container">
          <div className="layers">
            <span className="chip bass">BASS</span>
            <span className="chip chords">CHORDS</span>
            <span className="chip drums">DRUMS</span>
            <span className="chip lead">LEAD</span>
          </div>
          <p
            style={{
              textAlign: "center",
              color: "var(--text-dim)",
              marginTop: 18,
              fontSize: 14,
            }}
          >
            Four layers. One synth. A shared shimmer river.
          </p>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="section">
        <div className="container">
          <div className="section-head">
            <div className="kicker">What makes it sing</div>
            <h2>Everything you need to jam, nothing you don&apos;t.</h2>
            <p>
              Aether strips a DAW down to the part that&apos;s actually fun —
              playing — and makes every sound reachable in a tap.
            </p>
          </div>

          <div className="features">
            <article className="card">
              <div className="dot bass">≋</div>
              <h3>One synth, everywhere</h3>
              <p>
                A single Vital-style wavetable engine powers bass, chords and
                lead. Morph sine to saw to square, sweep the filter, shape the
                envelope, and save to a global sound library.
              </p>
            </article>

            <article className="card">
              <div className="dot lead">◆</div>
              <h3>Play, don&apos;t program</h3>
              <p>
                The lead is performed live on a scale-locked pad grid — every
                pad is in key, so there are no wrong notes. Hold pads for chords,
                slide for glissando, ride the filter-morph ribbon.
              </p>
            </article>

            <article className="card">
              <div className="dot chords">✦</div>
              <h3>The shimmer river</h3>
              <p>
                A shared shimmer-reverb send any track can attach to or detach
                from with a tap — add lush, blooming octaves to exactly the
                tracks you want.
              </p>
            </article>

            <article className="card">
              <div className="dot drums">▦</div>
              <h3>Stack of layers</h3>
              <p>
                Start every layer from a curated loop, kit or chord progression,
                then swap any of them in one tap. Per-track faders, mute, and
                live tempo keep the groove in your hands.
              </p>
            </article>

            <article className="card">
              <div className="dot neutral">●</div>
              <h3>Record your jam</h3>
              <p>
                Capture a take straight to a file and grab it from the Files app.
                Transpose the bass, shift the lead octave, change tempo live —
                then hit record.
              </p>
            </article>

            <article className="card">
              <div className="dot neutral">⛶</div>
              <h3>Yours, on device</h3>
              <p>
                Everything stays on your phone. No account, no analytics, no
                network calls. Recordings only leave if you export them yourself.
              </p>
            </article>
          </div>
        </div>
      </section>

      {/* Screens */}
      <section id="screens" className="section">
        <div className="container">
          <div className="section-head">
            <div className="kicker">A look inside</div>
            <h2>Designed to disappear into the music.</h2>
            <p>
              A deep, dim interface that keeps the focus on sound — with a color
              for every layer.
            </p>
          </div>
          <div className="shots">
            {[
              { src: "/shots/lead.png", alt: "Live scale-locked lead pad grid" },
              { src: "/shots/synth.png", alt: "Wavetable synth editor" },
              { src: "/shots/chords.png", alt: "Chord progression editor" },
              { src: "/shots/sounds.png", alt: "Global sound library" },
            ].map((s) => (
              <div className="shot" key={s.src}>
                <Image src={s.src} alt={s.alt} width={1284} height={2778} />
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Privacy band */}
      <section id="privacy" className="section">
        <div className="container privacy-band">
          <div className="kicker" style={{ color: "var(--drums)" }}>
            Privacy
          </div>
          <div className="big">Aether collects no data. None.</div>
          <p style={{ color: "var(--text-muted)" }}>
            No accounts. No analytics. No tracking. No network calls. Your jams
            and recordings live on your device and only go somewhere else if you
            choose to export them.
          </p>
          <p>
            <a href="/privacy">Read the full privacy policy →</a>
          </p>
        </div>
      </section>

      {/* CTA */}
      <section className="section" style={{ borderTop: "none" }}>
        <div className="container">
          <div className="cta-band">
            <h2>Plug in headphones and start jamming.</h2>
            <p>
              Aether — Melodic Jam is a one-time download. No subscription, no
              sign-up.
            </p>
            <a href={APP_STORE_URL} className="btn btn-primary">
              Download on the App Store
            </a>
          </div>
        </div>
      </section>

      <Footer />
    </>
  );
}
