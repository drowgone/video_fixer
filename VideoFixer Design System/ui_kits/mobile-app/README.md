# VideoFixer — Mobile App UI Kit

A high-fidelity, interactive recreation of the VideoFixer Android app's three
primary tabs, **refined for UI/UX**. Built from the Flutter source
(`lib/screens/home_screen.dart`, `history_screen.dart`, `settings_screen.dart`,
`main.dart`) — not from screenshots.

Open `index.html` and tap the bottom navigation to move between tabs.

## Screens

| Tab | File | What it shows |
|-----|------|----------------|
| **Asosiy** (Home) | `HomeScreen.jsx` | The unified state card: `pick → selected → processing → done`. Tap **Video Tanlash**, then **Videoni qayta ishlash** to watch the animated pipeline. |
| **Videolar** (History) | `HistoryScreen.jsx` | Video list with status badges, always-visible status filter, and List / Grid / Compact views (cycle via the top-right toggle). |
| **Sozlamalar** (Settings) | `SettingsScreen.jsx` | Connected YouTube channels with subs/videos, active toggles, and the Google connect CTA. |

Shared chrome lives in `AppShell.jsx` (dark Android frame, status bar, Material
`NavigationBar` with the live green *processing* dot and blue *queue* badge).
Primitives are in `VFKit.jsx`; mock data in `vf-data.js`.

## What was improved (vs. the shipping app)

These are deliberate UX refinements, all kept inside the existing brand
(dark `#0F0F0F`, YouTube red `#FF0000`, Roboto, Material Symbols, Uzbek copy):

- **Status clarity** — emoji-in-chip badges (`✅ Yuklangan`, `⏳ Jarayonda`)
  replaced with a calmer **colored-dot + label** chip system. Live states
  (uploading / queued) pulse.
- **Processing transparency** — the Home processing state gains a 3-stage
  **stepper** (Analiz → Konvertatsiya → Saqlash) above the progress bar, so the
  user knows *where* in the pipeline they are, not just a percentage.
- **Findable filtering** — the History status filter, previously buried in a
  bottom sheet, is now an **always-visible segmented row** with live counts.
- **Cleaner cards** — denser, consistent list rows; faithful tinted-icon
  thumbnails with format + duration tags.
- **Settings hierarchy** — channel cards show an active toggle, stats with
  icons, and a per-channel "Standart sozlamalar" action; a single prominent
  connect CTA replaces the floating button.

## Notes

- **Icons** use **Material Symbols Rounded** (the app's Material icon system),
  loaded from Google Fonts via `styles.css`. They render as glyphs in any real
  browser. *Caveat:* DOM-rasterized screenshots (html-to-image) cannot draw
  icon-font ligatures and will show the raw icon name as text — this is a
  capture-tool limitation, not a rendering bug.
- Thumbnails use the app's own **fallback** treatment (tinted box + glyph),
  since no real video frames ship with the source.
- `assets/google_logo.png` is referenced but absent in the source; the Google
  connect button uses the same blue-"G" fallback the app falls back to.
