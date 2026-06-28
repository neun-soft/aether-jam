import type { Metadata } from "next";
import Link from "next/link";
import { Nav, Footer, CONTACT_EMAIL } from "../components";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Aether collects no data. No accounts, no analytics, no network calls — everything stays on your device.",
};

export default function Privacy() {
  return (
    <>
      <Nav />
      <main className="prose">
        <Link href="/" className="back">
          ← Back to Aether
        </Link>
        <h1>Privacy Policy</h1>
        <p className="updated">Last updated: June 27, 2026</p>

        <p className="lead">
          Aether is built to collect nothing about you. There are no accounts,
          no analytics, no advertising, and no network calls. This policy
          explains that in full.
        </p>

        <h2>Data we collect</h2>
        <p>
          <strong>None.</strong> Aether (&ldquo;the app&rdquo;) does not collect,
          store, transmit, or share any personal data. We have no servers that
          receive information from the app, and the app makes no network requests
          to us or to any third party.
        </p>

        <h2>What stays on your device</h2>
        <ul>
          <li>
            Your projects, sounds, and settings are saved locally on your device.
          </li>
          <li>
            Recordings you make are written to local files on your device. They
            are never uploaded anywhere.
          </li>
        </ul>
        <p>
          This information never leaves your device unless you explicitly choose
          to export or share a file — for example, by saving a recording through
          the Files app or sharing it with another app. At that point, the data
          is handled by Apple&apos;s system features and the destination you
          choose, under their respective terms.
        </p>

        <h2>Analytics and tracking</h2>
        <p>
          The app contains no analytics SDKs, no advertising identifiers, and no
          tracking technologies of any kind. We do not build a profile of you and
          cannot, because we receive nothing.
        </p>

        <h2>Third-party services</h2>
        <p>
          Aether does not integrate any third-party services, accounts, or
          login providers. Microphone, audio, and file access are handled
          entirely on-device by iOS, and any permissions you grant are used only
          to make the app work — never to collect data.
        </p>

        <h2>Children&apos;s privacy</h2>
        <p>
          Aether is rated 4+ and is suitable for all ages. Because the app
          collects no data from anyone, it collects no data from children.
        </p>

        <h2>Changes to this policy</h2>
        <p>
          If we ever change how the app handles data, we will update this page
          and revise the date above. Material changes will be reflected in an app
          update and described here.
        </p>

        <h2>Contact</h2>
        <p>
          Questions about this policy? Email{" "}
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.
        </p>
      </main>
      <Footer />
    </>
  );
}
