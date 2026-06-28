import type { Metadata } from "next";
import Link from "next/link";
import { Nav, Footer, CONTACT_EMAIL } from "../components";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "The terms governing your use of the Aether app by Neun.",
};

export default function Terms() {
  return (
    <>
      <Nav />
      <main className="prose">
        <Link href="/" className="back">
          ← Back to Aether
        </Link>
        <h1>Terms of Service</h1>
        <p className="updated">Last updated: June 27, 2026</p>

        <p className="lead">
          These Terms of Service (&ldquo;Terms&rdquo;) govern your use of the
          Aether mobile application (&ldquo;Aether,&rdquo; or &ldquo;the
          app&rdquo;), provided by Neun (&ldquo;we,&rdquo; &ldquo;us,&rdquo; or
          &ldquo;our&rdquo;). By downloading or using the app, you agree to these
          Terms.
        </p>

        <h2>1. License</h2>
        <p>
          We grant you a personal, non-exclusive, non-transferable, revocable
          license to download and use Aether on Apple devices you own or control,
          for your personal, non-commercial and commercial music-making purposes,
          in accordance with these Terms and Apple&apos;s App Store Terms of
          Service.
        </p>

        <h2>2. Your content</h2>
        <p>
          Any music, recordings, and projects you create with Aether are yours.
          We claim no ownership over your output and, because the app collects no
          data, we never receive it. You are responsible for backing up files you
          care about.
        </p>

        <h2>3. Acceptable use</h2>
        <p>You agree not to:</p>
        <ul>
          <li>
            Reverse engineer, decompile, or attempt to extract the source code of
            the app, except where permitted by law;
          </li>
          <li>
            Resell, redistribute, or sublicense the app itself;
          </li>
          <li>
            Use the app in any way that violates applicable law or infringes the
            rights of others.
          </li>
        </ul>

        <h2>4. Intellectual property</h2>
        <p>
          The app, including its design, code, sounds, presets, and branding, is
          owned by Neun and protected by intellectual property laws. These Terms
          do not grant you any rights to our trademarks or branding.
        </p>

        <h2>5. Updates and availability</h2>
        <p>
          We may release updates that add, change, or remove features, and we may
          discontinue the app at any time. We are not obligated to provide any
          particular feature, update, or level of availability.
        </p>

        <h2>6. Disclaimer of warranties</h2>
        <p>
          The app is provided &ldquo;as is&rdquo; and &ldquo;as available,&rdquo;
          without warranties of any kind, whether express or implied, including
          but not limited to merchantability, fitness for a particular purpose,
          and non-infringement. We do not warrant that the app will be
          uninterrupted, error-free, or free of harmful components.
        </p>

        <h2>7. Limitation of liability</h2>
        <p>
          To the maximum extent permitted by law, Neun shall not be liable for
          any indirect, incidental, special, consequential, or punitive damages,
          or any loss of data, including the loss of recordings or projects,
          arising out of or related to your use of the app.
        </p>

        <h2>8. Apple</h2>
        <p>
          Aether is distributed through the Apple App Store. Apple is not a party
          to these Terms and is not responsible for the app or its content. The
          App Store Terms of Service also apply to your use of the app.
        </p>

        <h2>9. Changes to these Terms</h2>
        <p>
          We may update these Terms from time to time. Changes take effect when
          posted on this page, and the date above will be revised. Continued use
          of the app after changes constitutes acceptance.
        </p>

        <h2>10. Contact</h2>
        <p>
          Questions about these Terms? Email{" "}
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.
        </p>
      </main>
      <Footer />
    </>
  );
}
