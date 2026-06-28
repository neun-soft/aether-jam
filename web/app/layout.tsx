import type { Metadata, Viewport } from "next";
import { Space_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const display = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-display",
  display: "swap",
});

const mono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-mono",
  display: "swap",
});

const SITE_URL = "https://aether.neunsoft.com";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "Aether — Melodic Jam",
    template: "%s · Aether",
  },
  description:
    "Build melodic-house tracks from your phone — stack bass, chords, drums and a live lead, shape every sound with one wavetable synth, and dip any track into the shimmer river.",
  keywords: [
    "synth",
    "melodic house",
    "wavetable",
    "music maker",
    "groovebox",
    "iOS music app",
    "loop jam",
    "Aether",
    "Neun",
  ],
  authors: [{ name: "Neun" }],
  applicationName: "Aether",
  openGraph: {
    type: "website",
    url: SITE_URL,
    siteName: "Aether",
    title: "Aether — Melodic Jam",
    description:
      "Jam progressive & melodic house from your phone. One wavetable synth, a stack of layers, and a shared shimmer river.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Aether — Melodic Jam",
    description:
      "Jam progressive & melodic house from your phone. One wavetable synth, a stack of layers, and a shared shimmer river.",
  },
  icons: {
    icon: [{ url: "/favicon.svg", type: "image/svg+xml" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#0a0c12",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${display.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
