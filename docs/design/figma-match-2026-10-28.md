# Estran — M3 Figma match (2026-10-28)

Reference: `docs/design/estran-maquette-v1.pdf` — Figma **« Estran - maquette v1 »**,
page `v3 kit iOS 27`, four frames at 402 × 874, exported 2026-10-28.
`DESIGN_REFERENCE.md` remains the written source of truth; the PDF frames are the
visual one.

Evidence: `build/ax5/medium/export/*.png` and `build/ax5/ax5/export/*.png`
(simulator, iPhone 18 Pro, iOS 27). Text captured from the app, not from Figma.

**Placeholders are not defects.** The frames use the 14-spot catalog (Cap Ferret,
Lacanau, Pyla, Le Porge) and a « coef 92 »; v1 ships **two gauged spots** and
displays **no coefficient** (`DESIGN_REFERENCE.md` §3, §4.0; review Z23). Those
differences are product decisions, not layout gaps.

## 1. Frame 01 — Accueil

| Element | Frame | App | Verdict |
|---|---|---|---|
| Spot pill (pin + name) | top-left, glass capsule | in the scroll content above the title, shows the spot name | **MATCH** after the fix below |
| `Données d'exemple` badge | top-right | right of the pill, stacks under it at AX sizes | **MATCH** (prototype artifact, DEBUG only) |
| Large title + subtitle | « Maintenant » + « spot · hh mm » | same | **MATCH** |
| Activity picker | one translucent track, 5 segments, white selected pill | 5 separate glass capsules in a horizontal scroll, white selected | **PARTIAL** — see §5 |
| Answer card | label, giant word + icon, reason, detail, all centred | centred after this pass | **MATCH** |
| Next window card | icon, « Prochain bon créneau », range, « Puis demain… » | same; the second line appears only when a window is running | **MATCH** |
| Conditions row | 4 tiles side by side | 4 tiles side by side, 2 from `.xLarge`, 1 at AX | **MATCH** after the fix below |
| Tip | turquoise sparkle + one sentence | `TipCard`, same position | **MATCH** |
| Tab bar | 4 tabs, `Maintenant` active | same, native Liquid Glass | **MATCH** |
| Baignade | not in this frame | `SwimmingAdvisoryCard` replaces the verdict card | **MATCH** by design (§3.1 note) |

Fixes applied in this pass:

1. The spot pill lived in the navigation toolbar, where `.buttonStyle(.glass)`
   collapsed it to its pin icon and clipped the name (visible in the first
   medium screenshots). It now sits in the content, above the title, and stacks
   with the badge at accessibility sizes.
2. The answer card was left-aligned; the frame centres it. The label, verdict,
   reason and detail are centred now.
3. The conditions grid was 2 × 2 at every size; the frame shows four in a row.
   It is now 4 columns up to `.large`, 2 from `.xLarge`, 1 at accessibility
   sizes. Captions follow the frame (« baisse », « km/h O », « 12 s »,
   « ensoleillé ») and the spoken label keeps the full sentence.

## 2. Frame 02 — Détail spot (chart, metrics, créneaux)

**Built 2026-10-28.** `Estran/Features/SpotDetail/`:

| Frame element | App | Verdict |
|---|---|---|
| Back chevron + `Données d'exemple` badge | native back button; badge stacks under the title at AX sizes | **MATCH** |
| Title + subtitle « spot · jour » | « Arcachon-Eyrac » + « Bassin d'Arcachon · mercredi 28 oct. » | **MATCH** (subtitle uses the area and the date: the tide-station names are internal codes and the coefficient is not shown, review Z23) |
| Chart card: header, next event, good window, curve, band, 24 h axis | Swift Charts curve with the day's 10-min samples, green good windows, dashed « now » rule and dot, next extremum marked with its height, 0/6/12/18/24 h | **MATCH**, with one clarification: the header names the activity (« Bon créneau surf · … »), because the bands belong to the activity selected on Home |
| `Favori` heart pill | **dropped on purpose** | **Decision 2026-11-02 (2a)** — two spots, one selection: favourites add an state to sync for no user gain. Recorded in `DESIGN_REFERENCE.md` §3.2; the model stays in the schema for a later release |
| Metrics row: Vent / Houle / Météo | three tiles, same wording | **MATCH** |
| Créneaux list, five rows | glass card, one row per activity, 44 pt, reflows at AX | **MATCH** in layout; **baignade shows the current level, never « Non, eau à 15° »** (`AGENTS.md` invariant 1) |
| « Me prévenir 1 h avant » | `AlertOptInToggle`, the same App Group key as Alertes | **MATCH** |

Entry point: « Voir le détail » on the map card, pushed in the Spots tab's
`NavigationStack`, tab bar hidden on the detail. No third entrance.

## 3. Frame 03 — Choix activité

**Built 2026-10-28.** `Estran/Features/ActivityPicker/ActivityPickerView.swift`,
presented as a full-screen cover on first launch (once, flag in the App Group)
and from Réglages → Activité.

| Frame element | App | Verdict |
|---|---|---|
| Close (xmark) + « Activité » + confirm (check) | glass round buttons, both dismiss | **MATCH** |
| « Tu fais quoi ? » + subtitle | same copy | **MATCH** |
| Five rows: icon, name, spot, answer | same, with the current spot on each row | **MATCH** (the 2-spot catalog means every row names the same spot — honest in v1) |
| Selected row: turquoise ring + check | ring + filled check + `.isSelected` trait | **MATCH** |
| Baignade « Non, baïnes et eau à 15° » | permanent warning + current level, never Oui/Non | **Deviation required by invariant 1** |

The onboarding is skippable without choosing: the Home default is a real
activity, not an empty state.

## 4. Frame 04 — Widget et Live Activity

| Element | State |
|---|---|
| Dynamic Island expanded (tide + « dans 1 h 20 ») | view exists, **data not wired** (M5); the swimming disclaimer is now part of the expanded region |
| Lock-screen Live Activity | view exists, data not wired; verdict now carries an icon and follows `isGo` |
| Home widget, medium, multi-activity list | **MISSING** — `ConditionsWidget` is a 4-label placeholder; `GoWidget` shows one answer |
| Verdict badges in the widget list | not implemented |

Nothing in this frame can be matched before the M5 App Group data path exists.
The layout work already done (icons, labels, disclaimer) is view-level only.

## 5. Deliberate deviation to confirm — the activity picker

The frame draws five segments inside **one** translucent track. The app draws
five separate glass capsules inside a `GlassEffectContainer`, so adjacent pills
merge as the system does (`ARCHITECTURE_PLAN.md` §12.3). Both read as a
segmented control; only the track is different.

`DESIGN_REFERENCE.md` §3.1 describes the frame (one track), §7.3 asks for native
glass. The two cannot both be literal. Recommendation: keep the native glass and
record the deviation in §3.1, since a hand-drawn track on top of `glassEffect`
would be the pre-iOS 26 look the same document forbids.

## 6. What this report does not cover

- Pixel-perfect spacing and type sizes: the frames are compared structurally,
  not overlaid. A 1:1 diff needs Figma's inspector values per node.
- Colour: the palette is audited separately (`docs/accessibility/contrast-audit.md`).
- Axes and states the frames do not draw (loading, unavailable, night, alerts
  denied) — those follow `DESIGN_REFERENCE.md` and the M3 checklist.
