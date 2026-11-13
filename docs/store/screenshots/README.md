# App Store screenshots

Assets of the Estran 1.0.0 product page (fr-FR), submitted 2026-11-13.

| Folder | What | Size |
|---|---|---|
| `appstore-6.3/` | The 7 styled frames uploaded to App Store Connect (iPhone slot) | 1206 × 2622 |
| `landscape/` | Styled two-column landscape frame (not uploaded) | 2868 × 1320 |
| `header/` | Product page header banner (« en-tête personnalisé », not uploaded yet) | 5244 × 2950, 3840 × 1646 |
| `raw/` | Raw simulator captures (iPhone 18 Pro Max, live data, dev 3ccbabf) and the owner's device widget capture with the dock removed | 1320 × 2868 |
| `contact-sheet.png` | Overview of every frame | — |

Rebuild everything with `python3 docs/store/frames-src/render.py` (headless Google
Chrome, no other dependency). Intermediate HTML and the 1320 × 2868 set go to
`build/store/` (git-ignored); the committed outputs above are rewritten in place.
Captions and layout live in `render.py`. Store copy: `docs/store/fiche-app-store.md`.

Rules for any new capture: real data only (never the « Données d'exemple » badge),
no « Oui » shown for swimming, no third-party app icons (crop the dock), status bar
with the real clock.
