# Aether — website

Marketing site + legal pages for **Aether — Melodic Jam** (the Neun iOS app),
deployed at **aether.neunsoft.com**.

Built with Next.js (App Router) + TypeScript. No CSS framework — the theme in
`app/globals.css` mirrors the app's own design tokens (`Aether/DesignSystem/Theme.swift`).

## Pages

| Route       | Purpose                                  |
| ----------- | ---------------------------------------- |
| `/`         | Landing page                             |
| `/privacy`  | Privacy policy (required by App Store)    |
| `/terms`    | Terms of service                         |
| `/support`  | Support / FAQ (App Store Support URL)     |

## Develop

```sh
cd web
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
```

## Deploy to Vercel

This site lives in the `web/` subdirectory of the Aether app repo.

1. Import the repo in Vercel.
2. Set **Root Directory** to `web`.
3. Framework preset: **Next.js** (auto-detected). No env vars needed.
4. Add the custom domain **aether.neunsoft.com** in Project → Settings → Domains,
   and point a CNAME from `aether` → `cname.vercel-dns.com` in the neunsoft.com DNS.

## Before launch — fill these in

- `app/components.tsx` → `APP_STORE_URL`: replace the placeholder App Store ID
  once the listing is live.
- `support@neunsoft.com` mailbox/forwarding should exist (used on privacy,
  terms, support, and footer).
- Screenshots live in `public/shots/` (copied from `store_screens_6.7/`).
