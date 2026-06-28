import type { Metadata } from "next";
import Link from "next/link";
import { Nav, Footer, CONTACT_EMAIL } from "../components";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Get help with Aether — answers to common questions and how to reach us.",
};

export default function Support() {
  return (
    <>
      <Nav />
      <main className="prose">
        <Link href="/" className="back">
          ← Back to Aether
        </Link>
        <h1>Support</h1>
        <p className="updated">We&apos;re a small team and we read every email.</p>

        <p className="lead">
          Something not working, or have a feature in mind? Email{" "}
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> and we&apos;ll
          get back to you.
        </p>

        <h2>Frequently asked</h2>

        <h2 style={{ fontSize: 17 }}>Where are my recordings saved?</h2>
        <p>
          Recordings are written to local files on your device. Open the Files
          app to find, move, or share them. Nothing is uploaded anywhere.
        </p>

        <h2 style={{ fontSize: 17 }}>Do I need an account?</h2>
        <p>
          No. Aether has no accounts and no sign-up. Download it and start
          jamming.
        </p>

        <h2 style={{ fontSize: 17 }}>Does Aether work offline?</h2>
        <p>
          Yes — entirely. The app makes no network calls, so everything works
          with no connection.
        </p>

        <h2 style={{ fontSize: 17 }}>I hear no sound. What should I check?</h2>
        <p>
          Make sure your device isn&apos;t on silent mode and the volume is up.
          Headphones are recommended for the best low end. If a track is muted,
          un-mute it from the stack view.
        </p>

        <h2 style={{ fontSize: 17 }}>What devices are supported?</h2>
        <p>
          Aether runs on iPhone with iOS 17 or later.
        </p>

        <h2>Still stuck?</h2>
        <p>
          Email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> with your
          device model and iOS version and we&apos;ll help you out.
        </p>
      </main>
      <Footer />
    </>
  );
}
