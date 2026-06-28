import Link from "next/link";
import Image from "next/image";

export const APP_STORE_URL = "https://apps.apple.com/app/id0000000000";
export const CONTACT_EMAIL = "support@neunsoft.com";

export function Nav() {
  return (
    <nav className="nav">
      <div className="container nav-inner">
        <Link href="/" className="brand">
          <Image
            className="glyph"
            src="/logo.svg"
            alt="Aether logo"
            width={30}
            height={30}
            priority
          />
          Aether
        </Link>
        <div className="nav-links">
          <Link href="/#features">Features</Link>
          <Link href="/#screens">Screens</Link>
          <Link href="/#privacy">Privacy</Link>
          <span className="nav-cta" aria-disabled="true">
            Coming soon
          </span>
        </div>
      </div>
    </nav>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="container footer-inner">
        <div>
          <div className="brand" style={{ marginBottom: 10 }}>
            <Image
              className="glyph"
              src="/logo.svg"
              alt="Aether logo"
              width={30}
              height={30}
            />
            Aether
          </div>
          <small>A Neun app · Made for iPhone</small>
        </div>
        <div className="footer-links">
          <Link href="/#features">Features</Link>
          <Link href="/support">Support</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
          <a href={`mailto:${CONTACT_EMAIL}`}>Contact</a>
        </div>
      </div>
      <div className="container" style={{ marginTop: 28 }}>
        <small>© {new Date().getFullYear()} Neun. All rights reserved.</small>
      </div>
    </footer>
  );
}
