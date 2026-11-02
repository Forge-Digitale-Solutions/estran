# Estran — Design Reference (from Figma)

> Extracted from the Figma file **« Estran - maquette v1 »**, page **« v3 kit iOS 27 »** (latest version — the page referenced by the provided URL).
> This is the source of truth for the UI. Internal technical doc (English); UI copy is French.

- **File**: `oQzyhUddb0oCLL2hlIWsM1`
- **Page used**: `v3 kit iOS 27` (frames `12:3`, `12:116`, `12:248`, `12:335`)
- **Frame size**: 402 × 874 (iPhone)
- **Offline copy**: `docs/design/estran-maquette-v1.pdf` (Figma export, 4 frames,
  2026-10-28) — the version the M3 match is checked against when Figma is not
  open.

---

## 1. Color palette

| Token | Hex | Usage |
|---|---|---|
| `oceanDeepTop` | `#0A3D62` | App background gradient (top) |
| `oceanDeepBottom` | `#031426` | App background gradient (bottom) |
| `navyInk` | `#06223F` | Text on sand/light backgrounds ("Données d'exemple"), segmented selected text |
| `turquoise` | `#30D5C8` | Primary accent: active tab, spot pin, tide curve, AI icon, highlighted values |
| `blueGlow` | `#0091FF` | Decorative glow (blur ellipse) |
| `sand` | `#F2E3C2` | Badge background, tile icons, secondary strokes |
| `white` | `#FFFFFF` | Primary text, icons |
| `oui` | `#34C759` | **Oui** (go) — big badge, positive slots, positive widget states |
| `ouiDark` | `#03210F` | Dark green text on a green Live Activity pill |
| `non` | `#FF6B5B` | **Non** (no-go) — coral, negative slots/reasons |
| `glassFill` | `#FFFFFF` + `#BFD9FF` | Liquid Glass card fill (white + light blue tint) |
| `segmentedBg` | `#767680` | Segmented control track (system gray) |
| `chartHighlight` | `#30D158` | Good-window highlight on the tide chart |

**Background**: vertical linear gradient `#0A3D62 → #031426`, with two blurred `Glow` ellipses (`#30D5C8`, `#0091FF`).

> Note: the exact glass opacity is represented in Figma by a white fill + `#BFD9FF` tint. In SwiftUI, prefer native `.glassEffect` / glass materials and tune tint to match, rather than hard-coding alpha.

---

## 2. Typography

Figma uses **Inter** as a placeholder. In iOS, map to the system family — **SF Pro** (body) / **SF Pro Rounded** (display numerals and the Oui/Non badge, for the "ocean" feel).

| Role | Size | Weight |
|---|---|---|
| Large title | 34 | Bold (700) |
| Metric value (tiles detail) | 22 | Semibold (600) |
| Body / emphasized | 17 | Semibold (600) |
| Body / label | 17 | Regular (400) |
| Subtitle / secondary | 15 | Regular (400) |
| Button / caption / slot result | 13 | Semibold (600) or Medium (500) |
| Small label / unit | 11 | Regular (400) |
| Tab label | 10 | Semibold (600) |
| **Giant Oui/Non (Home)** | **76** | Bold (700) |
| Widget Oui/Non (medium) | 48 | Bold (700) |
| Lock-screen clock | 96 | Bold (700) |

Weight mapping: 400 → `.regular`, 500 → `.medium`, 600 → `.semibold`, 700 → `.bold`.

### 2.1 Dynamic Type — AX5 is the baseline, not a retrofit

Estran is an iOS 27 showcase: a screen that breaks at large text undermines the product. **Every screen is built at AX5 from its first commit**; AX5 and VoiceOver are **M3 gates** (`worksplit.md` §6) and are re-verified on device at M6.

**Scaling rule.** Text uses semantic styles only — never a literal `Font.system(size:)` for copy that carries meaning. The table records the reference size at the default content size; the AX5 value comes from the system curve and is verified with Xcode's Environment Overrides, not hand-computed.

| Role | SwiftUI style | Reference size | At AX5 |
|---|---|---|---|
| Giant Oui/Non (Home) | `.largeTitle` + `.fontWeight(.bold)` | 76 | scales with the curve — **never clamped, never `.lineLimit(1)`** |
| Widget Oui/Non | `.largeTitle` | 48 | scales; the widget switches to a stacked layout |
| Large title | `.title` | 34 | scales |
| Metric value (tiles) | `.title3` | 22 | scales |
| Body / label | `.body` | 17 | **53** (system anchor for AX5) |
| Subtitle / secondary | `.subheadline` | 15 | scales |
| Caption / slot result | `.caption` | 13 | scales |
| Small label / unit | `.caption2` | 11 | scales |

Non-text metrics that must grow with the text (icon-to-label gaps, badge insets, tile minimum height) use `@ScaledMetric(relativeTo:)`, not a constant.

**Reflow ladder.** The layout changes shape, it does not shrink.

| Content size | Layout |
|---|---|
| ≤ `.xxLarge` | side-by-side allowed: badge + reasons, 2×2 condition tiles, horizontal `SpotSwitcher` chips |
| `.xxxLarge` … `.accessibility1` | horizontal pairs become `VStack`; the 2×2 tile grid becomes a single column |
| ≥ `.accessibility1` | the 5-segment `ActivitySegmentedControl` becomes a vertical list (or a `Menu`); the `SpotSwitcher` stacks its chips vertically |
| ≥ `.accessibility3` | the `TideChart` keeps its graphic height but gains a text summary row; `AnswerCard` drops any decorative glass padding that competes with the text |

**Hard rules.**

- No fixed `.frame(height:)` on a text container; use `.fixedSize(horizontal: false, vertical: true)` when a label must wrap rather than truncate.
- No `.lineLimit(1)` on a string that carries meaning (spot name, reason, verdict). Decorative overlines may truncate.
- Reflow is decided with `@Environment(\.dynamicTypeSize)` or `ViewThatFits`, not with manual font maths.
- `.dynamicTypeSize(...)` is allowed **only** with a written justification recorded in this section; none exists today, so no clamp is permitted in v1 code. A clamp must never hide a reflow bug.
- Widgets (S/M/L, Lock Screen) and the Live Activity / Dynamic Island presentations are checked at AX5 as soon as they exist; clipping at AX5 is a gate failure, not a polish item.

**Glass and state honesty (early M3 review; `ARCHITECTURE_PLAN.md` §12.3–§12.4, §13).**

- Surfaces are **iOS 27 glass** (`glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)`), never `.ultraThinMaterial`. The material is the pre-iOS 26 look and is banned from shipped surfaces. The swap stays behind `oceanGlassCard` / `oceanGlassCapsule`.
- Every tappable control is at least **44 × 44 pt** at the default text size; the chips and the spot button grow with Dynamic Type, they do not shrink below it.
- **Compact Dynamic Island is the only truncation exception.** Its trailing region is width-constrained by the system, so `.lineLimit(1)` is allowed there for the spot name; the full name is always available in the expanded presentation and in the app. No other meaningful string may truncate.
- **Swimming in the compact/minimal Dynamic Island** shows the alert glyph only: there is no room for « baïnes ». The word is carried by the expanded island, the lock screen, the widget and the card. Never remove the warning from those surfaces to compensate, and never restore the current level as the leading element.
- **No silent zero.** A missing tide event renders « — », never `0,0 m`: zero is a real chart height, not a neutral placeholder.
- **Unavailable ≠ none.** When data cannot answer the activity, the window card says « Créneaux indisponibles », never « Aucun créneau ».
- **No stale cross-spot state.** Changing spot clears conditions, forecast, decision and windows before the new data loads.
- **VoiceOver parity.** The answer card's label says everything the card displays, including the tide detail line.
- **The coefficient is not displayed in v1.** A word that raises a question the app cannot answer is noise.
- Dataset-derived facts (source date, labels) are read from the dataset, never hard-coded.

---

## 3. Screens inventory

> **Read this with §4.** The Figma frames were drawn with the 14-spot catalog, so the mockup copy names post-v1 spots (Cap Ferret, Lacanau, Pyla, Le Porge) and shows a « coef 92 ». **v1 renders the same layouts with the 2 shipped spots** — Pointe de Grave / Le Verdon and Arcachon-Eyrac. Spot names in the frames below are placeholders for the layout, not shipped content.
>
> **Coefficient in v1:** the engine computes the national Brest value but the model is **not validated** (`coefficientValidated = false`, review Z23). The coefficient is **not displayed at all**. Baignade is a risk level computed from the local predicted range, never a « Oui ». Any « coef 92 » in a mockup is a Figma placeholder.

### 3.1 — 01 Accueil (Home)

Vertical layout, deep-blue gradient background:

1. **Status bar** (9:41).
2. **Nav bar** — left: `Spot button` (pill, glass) with pin icon (turquoise) + spot name « Cap Ferret ». Right: a `Données d'exemple` sand badge (dev-only, **must be removed before ship**).
3. **Large title** — « Maintenant » (34 bold) + subtitle « Plage de l'Horizon · 12:52 ».
4. **Segmented control (activité)** — 5 segments: `Pêche · Surf · Bateau · Balade · Bain`. Selected segment = white pill with dark text; unselected = white text on translucent track.
5. **Answer card** (glass, radius 34):
   - Label « BON MOMENT POUR SORTIR ? » (13, uppercase).
   - Giant **« Oui »** (76 bold, green `#34C759`) — flips to **« Non »** in coral.
   - Reason line 1: « Marée basse à 14 h 12, vent faible. » (17 semibold) — **no coefficient in v1** (Z23).
   - Reason line 2: « Le banc reste découvert jusqu'à 15 h 40. » (15 regular).
   - **Baignade never uses this card.** It uses `SwimmingAdvisoryCard` in the order **title → warning → conditions → level**: a permanent coast-specific warning (« Toute l'année… »), a factual conditions line (« Vent 38 km/h · houle 1,5 m · eau 17 °C »), the non-current blockers in words (« vent fort », « houle trop forte », « eau froide », « la nuit », « orage »), then the **secondary** level (« Courants de marée estimés : faibles / modérés / forts / non estimés ») in caption, never `metricValue`. The blockers never raise the current level. No « Oui », no green `#34C759`, on any surface (app, widget, Live Activity, Siri).
6. **Next window card** (glass, radius 26): icon + « Prochain bon créneau » / « 13 h 10 à 15 h 40 » (17 semibold) / « Puis demain, 14 h 50 à 16 h 20 » (13 regular).
7. **Conditions row** — 4 tiles (glass, radius 22): `Marée` (1,2 m · basse), `Vent` (9 km/h NO), `Houle` (0,8 m · 11 s), `Météo` (17° · éclaircies). Each: icon (sand), value (17 semibold), label (11).
8. **Apple Intelligence section** — turquoise icon + generated tip: « Calme côté bassin, parfait pour les palourdes. Pense aux bottes. » (13 regular).
9. **Tab bar (Liquid Glass)** — 4 tabs: `Maintenant` (active, turquoise), `Spots`, `Alertes`, `Réglages`.
10. Home indicator.

### 3.2 — 02 Détail spot (Spot detail)

1. **Nav bar** — back chevron, `Données d'exemple` badge. **No `Favori` pill in v1** (decision 2026-11-02): with two spots and a single selection, a favourite adds an state to sync across app, widget and Siri for no user gain. The `FavoriteSpot` model stays in the SwiftData schema, unused, so the feature can ship later without a migration. The frame keeps the pill; the app deliberately does not render it.
2. **Large title** — « Arcachon » + subtitle « Jetée Thiers · lundi 26 oct. · coef 92 ».
3. **Chart card (Swift Charts)** (glass, radius 26):
   - Header « Marée » + « Basse 14 h 12 · 1,2 m » (turquoise).
   - « Bon créneau 13 h 10 à 15 h 40 ».
   - Tide curve (turquoise) with a **good-window highlight band** (green `#30D158`), x-axis labels `0 h 6 h 12 h 18 h 24 h`.
4. **Metrics row** — 3 tiles: `Vent` (12 km/h NO), `Houle` (1,4 m · O 11 s), `Météo` (17° éclaircies).
5. **Créneaux list (inset grouped)** (glass, radius 26) — one row per activity:
   - Pêche à pied → « 13 h 10 à 15 h 40 » (green)
   - Balade → « 10 h à 17 h 30 » (green)
   - Bateau → « 16 h 30 à 19 h » (green)
   - Baignade → « Non, eau à 15° » (coral)
   - Surf → « Non, trop petit » (coral)
6. **« Me prévenir 1 h avant »** toggle (notification opt-in).

### 3.3 — 03 Choix activité (Activity picker)

- Large title « Activité » + « Tu fais quoi ? » (34 bold) + subtitle « On te dit si c'est le bon moment, spot par spot. ».
- `Données d'exemple` badge.
- **List of the 5 activities**, each with a representative spot and a short answer:
  - Pêche à pied — Cap Ferret — « Oui, 13 h 10 à 15 h 40 » (green)
  - Surf — Lacanau, plage centrale — « Oui dès 17 h, 1,4 m 11 s » (green)
  - Bateau — Arcachon, passes — « Non, vent fort aux passes » (coral)
  - Balade — Pyla, dune — « Oui, sec jusqu'à 18 h » (green)
  - Baignade — Le Porge, océan — « Non, baïnes et eau à 15° » (coral)

### 3.4 — 04 Widget + Live Activity

Multiple mockups in one frame:

1. **Dynamic Island / compact Live Activity** — « Marée basse » / « dans 1 h 20 » + « Cap Ferret · 14 h 12 · coef 92 · pêche à pied : oui ».
2. **Lock-screen Live Activity** — « lundi 26 octobre », big clock « 12:52 » (96), « 9 km/h », « Pêche à pied » + « Oui » (green) + « jusqu'à 15 h 40 ».
3. **Expanded Live Activity** — « Pêche à pied » / « Cap Ferret » / « Oui » + « Début 13 h 10 » · « Basse 14 h 12 » (turquoise) · « Fin 15 h 40 ».
4. **Home-screen widget (medium 364×170)** — « Cap Ferret » + « Oui » (48 bold green) + « Jusqu'à 15 h 40 » + « pêche à pied ».
5. **Multi-activity widget** — 5 rows: Surf, Lacanau « Dès 17 h » (coral) · Balade, Pyla « Oui » · Bateau, passes « Non » · Bain, Le Porge « Non ».

### 3.5 — 05 Carte focus (2 spots)

The map is a **focus map**, not a browsing map (`ARCHITECTURE_PLAN.md` §12.1). It is the only place where a spot is chosen, and it shows exactly two.

1. **Map** — MapKit, the Bassin d'Arcachon and the Médoc coast framed so both spots are reachable by camera animation, no free zoom across the 90 km between them.
2. **Spot marker** — one marker for the selected spot only: a small glass callout with the spot name and the current verdict (`Oui` / `Non`), never a forest of pins.
3. **`SpotSwitcher`** — floating Liquid Glass capsule with two chips (Pointe de Grave / Arcachon-Eyrac), pinned above the tab bar; spec in §6.1.
4. **Spot card** — a compact glass card anchored to the bottom (above the switcher): spot name, verdict, next window, and a « Voir le détail » affordance to screen 02.
5. **Tab bar (Liquid Glass)** — same 4 tabs; `Spots` is active on this screen.

**States.** `default` · `switching` (camera animating, chips still tappable) · `dataUnavailable` (the selected spot has no dataset: the card says « Données indisponibles », the marker stays, the spot is never removed from the switcher).

**No third spot, no empty pin, no greyed out spot, no « bientôt ».** At two spots the switcher is sufficient; a list would add a tap for nothing.

---

## 4. Spots catalog

**v1 scope (D3 = Option A, Anthony 2026-10-27):** **2 gauged spots only** — Pointe de Grave / Le Verdon (station 15) and Arcachon-Eyrac (station 190). No estimated spot ships in v1: no « bientôt » entry, no estimated verdict, no « estimation — modèle local » copy.

**Post-v1 roadmap:** the 14-spot coastal scope below (Pointe de Grave → Arcachon / Pyla) is kept as the target catalog. Sections 4.1–4.4 are **roadmap, not shipped content**. The Figma's 5 spots are a representative subset.

> Coordinates below are the architect's proposed values (WGS84) and **must be verified against an authoritative source** (IGN / SHOM / OpenStreetMap) during M1 before being encoded in `EstranCore`.

### 4.0 v1 catalog (shipped)

| # | Spot | Lat | Lon | Tide reference (REFMAR) | Validation | Envelope |
|---|---|---|---|---|---|---|
| 1 | Pointe de Grave (Le Verdon-sur-Mer) | 45.570 | −1.062 | **`PORT-BLOC`** gauge 15 (fit) + `PORT_BLOC_GPM` 297 (QC) | **gauged** — « modèle local — station 15 » | ±75 min / ±0.60 m |
| 2 | Arcachon (Jetée Thiers / Eyrac) | 44.661 | −1.169 | **`ARCACHON_EYRAC`** gauge 190 | **gauged** — « modèle local — station 190 » | ±70 min / ±0.70 m |

**Swimming range (v11, calibrated on 2025):** `swimmingRange` per spot — 15 → `lowBelow 4.03` / `strongAt 4.63`; 190 → `3.58` / `4.18`. The qualifying-day count is specific to the calibration year; it is not a constant. It drives the swimming level, not the national coefficient.

`u_h` is the measured **one-sided** leave-one-year-out bound: **0.60 m** at 15, **0.70 m** at 190 (Z21/Z27). `u_t(15) = 75 min` and `u_t(190) = 70 min` are leave-one-year-out bounds (Z22/Z29); the 190 value also covers the SHOM 2025 low-water cross-check (Z19).

### 4.1 Médoc Atlantic coast (north → south) — post-v1 roadmap

| # | Spot | Lat | Lon | Tide reference (REFMAR) |
|---|---|---|---|---|
| 1 | Pointe de Grave (Le Verdon-sur-Mer) | 45.570 | −1.062 | **`PORT-BLOC`** gauge 15 (fit) + `PORT_BLOC_GPM` 297 (QC) — **gauged** |
| 2 | Soulac-sur-Mer (plage centrale) | 45.512 | −1.121 | gauge 15 + local correction — **estimated** |
| 3 | Montalivet-les-Bains | 45.363 | −1.148 | gauge 15 + local correction — **estimated** |
| 4 | Hourtin-Plage | 45.223 | −1.171 | gauge 15 + local correction — **estimated** |
| 5 | Carcans-Plage (Océan) | 45.074 | −1.195 | gauge 15 + local correction — **estimated** |
| 6 | Lacanau-Océan | 44.998 | −1.206 | gauge 15 + local correction — **estimated** |
| 7 | Le Porge-Océan | 44.884 | −1.237 | gauge 15 + local correction — **estimated** |
| 8 | Lège / Grand Crohot | 44.796 | −1.240 | gauge 15 + local correction — **estimated** |

### 4.2 Cap Ferret peninsula (post-v1 roadmap)

| # | Spot | Lat | Lon | Tide reference (REFMAR) |
|---|---|---|---|---|
| 9 | Cap Ferret (Pointe / Plage de l'Horizon) | 44.660 | −1.243 | gauge 190 at 7 km + local correction — **estimated** (distance is not validation) |

### 4.3 Bassin d'Arcachon (south shore) — post-v1 roadmap

| # | Spot | Lat | Lon | Tide reference (REFMAR) |
|---|---|---|---|---|
| 10 | Arcachon (Jetée Thiers / Eyrac) | 44.661 | −1.169 | **`ARCACHON_EYRAC`** gauge 190 — **gauged** |
| 11 | Pyla-sur-Mer (Dune du Pilat) | 44.586 | −1.221 | gauge 190 + local correction — **estimated** |

### 4.4 Bassin d'Arcachon interior (post-v1 roadmap)

For pêche à pied / baignade / bateau on the lagoon's north-east and south-east shores. **Post-v1 only.** All three are **estimated**: there is no gauge at Andernos, Arès or Gujan-Mestras, and the lagoon response is delayed and damped relative to Eyrac.

| Spot | Lat | Lon | Tide reference (REFMAR) |
|---|---|---|---|
| Andernos-les-Bains | 44.743 | −1.090 | gauge 190 + local lag/amplitude — **estimated** |
| Arès | 44.762 | −1.130 | gauge 190 + local lag/amplitude — **estimated** |
| Gujan-Mestras / La Hume | 44.632 | −1.066 | gauge 190 + local lag/amplitude — **estimated** |

### 4.5 Tide data route (0 €)

- **Primary source:** REFMAR observations (Licence Ouverte 2.0) → build-time least-squares harmonic analysis → embedded constants in `EstranCore/Resources`. No runtime API, no purchase, no subscription.
- **Reference gauges:** `ARCACHON_EYRAC` (190, RONIM, validated hourly source 4) for the Bassin; `PORT-BLOC` (15, RONIM, validated hourly source 4, 2024 excluded) for the ocean; `PORT_BLOC_GPM` (297, REFMAR, raw source 1) as an independent QC cross-check only. `BREST` (3, RONIM) provides the national coefficient reference.
- **Derived model, not a SHOM prediction.** The constants are our own computation. The UI says **« estimation »** / **« modèle local »**, never « données officielles ». Attribution: **« Source : REFMAR / Shom — Licence Ouverte 2.0 — données mises à jour le <date> »**. No SHOM logo.
- **D3 revised — Option A:** v1 ships **2 gauged spots** (Pointe de Grave, Arcachon-Eyrac). The 12 estimated spots are a **post-v1 roadmap**; the lag/FES2022 work is stopped for v1. « Mesure locale » is forbidden: the app never measures. « Estimation — modèle local » does not appear in v1.
- **Fail-closed gates:** the gate scans the **full interval** `[t − u_t, t + u_t]` (not the corners): minimum water height minus `u_h`, maximum distance to low water, phase-band intersection, daylight endpoints, **interval coverage** (midnight-safe) and the **horizon at `t + u_t`**. If the envelope straddles a threshold, the verdict is `Non` with « Marge insuffisante ». Per-station bounds: **15 → ±75 min / ±0.60 m**; **190 → ±70 min / ±0.70 m**. Derivation in the v6 sourcing report §6.5.
- **Validity horizon:** every station carries `validUntil` (fit end + **3 years**, Z28: 2029); the engine fails closed past it, and the gate checks the end of the envelope, not only the decision instant. The annual regeneration is a maintenance ritual, not a product expiry.
- **Baignade is a risk level, never a verdict:** the level uses the **local predicted tidal range** (`spot.swimmingRange`, calibrated in the generator) and the tide phase, not the national coefficient. `strong` at or above `strongAt` mid-tide, `moderate` inside the ±0.30 m grey band, `low` below it; a missing range is « Courants non estimés ». No `Oui` is ever shown for swimming. The permanent warning is in `SwimmingRiskLevel` and is shared by the app, the widget and the Live Activity.
- **Coefficient de marée:** the official coefficient is defined at **Brest** (`C = (H_h − H_b) / 6.10 × 100`, clamped 20…120). The engine now computes it from station 3, but the model is not validated (bias +1.75, 37 % within ±1), so the coefficient is **hidden in v1** and the pêche à pied gate is on the national scale at **72**.
- **Accuracy (v6, held-out 2025 complete year):** 190 RMSE 0.1605 m / bias −0.0062 / p95 0.3146 / max under-prediction 0.5032; 15 0.1467 / −0.0144 / 0.2983 / 0.3926; 3 0.1475 / −0.0147 / 0.2907 / 0.4776. D2 met at all three. The leave-one-year-out worst under-prediction sizes `u_h` (0.6059 at 190, 0.5113 at 15, both 2022). The 2026-H1 stress test is an anomalous-pressure year, not model drift (Z26). No accuracy claim at ungauged spots.
- **Currents:** the free 2D Gascogne atlas (2 km, 30 min, coefficients 45/95) cannot resolve the passes. The pass-current gate stays a documented, unvalidated heuristic; unknown phase → `.dataUnavailable`.
- **Officiality:** none. The derived dataset is not official and must not be described as such.

---

## 5. Activities & naming

- **Full labels**: Pêche à pied, Surf, Bateau, Balade, Baignade.
- **Short segmented labels** (Home): Pêche, Surf, Bateau, Balade, **Bain** (note: "Bain" is the short form of "Baignade" in the segmented control).
- Each activity maps to a `case` in the `Activity` enum, with `shortLabel` and `fullLabel`.

---

## 6. Components checklist

| Component | Notes |
|---|---|
| `GoBadge` | Giant Oui/Non, 76pt, green `#34C759` / coral `#FF6B5B` |
| `ConditionTile` | glass radius 22, icon (sand) + value (17 semibold) + label (11) |
| `AnswerCard` | glass radius 34, label + badge + 2 reason lines — **not for swimming** |
| `SwimmingAdvisoryCard` | glass radius 34, title → warning → conditions → level; level in caption, never Oui/green |
| `NextWindowCard` | glass radius 26 |
| `TideChart` | Swift Charts, turquoise curve + green good-window band, 0–24h axis |
| `ActivitySegmentedControl` | 5 glass chips in a `GlassEffectContainer`, white-tinted selected pill, 44 pt minimum |
| `ActivitySlotRow` | activity + time (green) or reason (coral) |
| `SpotButton` | glass pill, pin icon + name — **post-v1**, replaced in v1 by `SpotSwitcher` |
| `SpotSwitcher` | floating Liquid Glass switcher over the focus map, 2 chips (Pointe de Grave / Arcachon). Single source of spot selection in the app — see §6.1 |
| `TabBar` | Liquid Glass, 4 tabs (Maintenant/Spots/Alertes/Réglages) |
| `SampleDataBadge` | « Données d'exemple » sand badge — **dev only** |
| `AlertToggle` | « Me prévenir 1 h avant » — authorization re-read on appear; scheduling is an M4 dependency of the first TestFlight build |

### 6.1 `SpotSwitcher` — the only way to change spot

The v1 map is a **focus map with 2 spots** (`ARCHITECTURE_PLAN.md` §12.1). There are no pins to browse, no list of 14, no « bientôt »: the switcher is the whole navigation.

**Shape and placement.** A floating iOS 27 glass control (`glassEffect` in a `GlassEffectContainer`) pinned above the tab bar (or top-trailing when the map is the background), inset 16 pt, with two chips of equal width. The selected chip uses tinted glass (white tint); the unselected chip is plain glass. No colour-only selection: the selected chip also carries a check glyph, and the spot name is always written out. Each chip is at least 44 pt tall.

**Behaviour.**

1. Tap a chip → `SpotSelectionStore.select(spot)`.
2. The map camera animates between two fixed framings (`MapCameraPosition` + `withAnimation(.spring(response: 0.55, dampingFraction: 0.85))`); the app never free-zooms across the empty 90 km between the two spots.
3. The selected chip's tinted glass changes in place; no matched-geometry clone is drawn over a real glass surface.
4. The selected spot propagates to Home, spot detail, the widget configuration and Siri (`SpotEntity`) from the same store — there is exactly one selection in the app.

**States.** `default` (2 chips) · `switching` (camera in flight, chips remain tappable and the last committed selection is authoritative) · `dataUnavailable` (the selected spot has no dataset: the chip keeps the name, the card shows « Données indisponibles » — the chip is never removed, the spot never disappears).

**Dynamic Type.** ≤ `.xxLarge`: chips side by side, names on one line. ≥ `.accessibility1`: chips stack vertically, full width, and the capsule becomes a glass sheet anchored bottom. ≥ `.accessibility3`: the control degrades to a `Menu` whose label is the current spot — a 2-row stack would otherwise eat the map.

**VoiceOver.** Each chip is one element with `.isButton` and `.isSelected` on the active one; label = spot name, hint = « Affiche les conditions à Arcachon-Eyrac ». The container announces the current spot once on appearance (« Spot actuel : Pointe de Grave »), not on every camera move.

**Reduce Motion.** The camera jump becomes a cross-fade and the selection pill appears without sliding.

---

## 7. Implementation notes

1. **Inter → SF**: use the system font (SF Pro / SF Pro Rounded); do not bundle Inter.
2. **`Données d'exemple` badge** appears on 3 screens; it is a prototype artifact. Keep it behind a `#if DEBUG` flag only (or drop entirely).
3. **Liquid Glass** should be native (`.glassEffect`, glass materials, `.buttonStyle(.glass)`) — the `#FFFFFF + #BFD9FF` fill is Figma's approximation of that material.
4. **Green/coral are semantic** (Oui/Non); never use them decoratively. Text always accompanies the color (accessibility).
5. The **tide chart good-window band** is a real feature: the decision engine's `nextGoodWindow` is rendered directly on the curve.
6. The **Apple Intelligence tip** is distinct from the deterministic reason: reason = "why Oui/Non", tip = a friendly extra recommendation (also generated, also with fallback).
7. **Build at AX5 from the first commit** (§2.1). AX5 and VoiceOver are M3 gates, not M6 polish: a layout that only works at the default size is not done.
8. **The focus map is the only spot selector** (§3.5, §6.1). No pin list, no 14-spot catalog, no « bientôt »: the app states two places.
9. A `.dynamicTypeSize(...)` clamp needs a written justification in §2.1 before it enters the codebase; there is none today.
