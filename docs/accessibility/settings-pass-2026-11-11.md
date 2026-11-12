# M3 accessibility-settings pass (simulator evidence)

|                 |                                                                                          |
| --------------- | ---------------------------------------------------------------------------------------- |
| **Date**        | 2026-11-11                                                                                |
| **Device**      | iPhone 18 Pro simulator, iOS 27.2, UDID `6D875634-293F-4D8B-8227-B8DEA7CAC589`             |
| **Toolchain**   | Xcode 27.2 (27B52), `xcodebuild`, `-derivedDataPath build/DerivedData`                     |
| **Branch**      | `dev`                                                                                     |
| **Gate**        | `worksplit.md` §6 M3 — « Increase Contrast, Reduce Motion, Reduce Transparency on the glass surfaces, and the `SpotsView` glass measured over map tiles » |
| **Kind**        | Runtime pass: settings toggled in the simulator, screenshots per configuration, pixel sampling |
| **Tour**        | `EstranUITests/AccessibilityTourUITests` (12 screenshots per run)                          |
| **Runs**        | 5 configurations, 18 attachments each, all runs green                                     |

## 1. Verdict

**All three settings are implemented and verified in the render**; the fourth
configuration (dark appearance) changes nothing in the app, by design.

1. **Reduce Transparency works.** Toggled through
   `com.apple.Accessibility/EnhancedBackgroundContrastEnabled`, read back, device
   rebooted. Every `oceanGlassCard` / `oceanGlassCapsule` surface goes through one
   modifier (`GlassStyles.swift:117-164`), and every sampled instance — Home
   answer card, map card, Alerts card, picker rows — renders the opaque
   `navyInk` fill: the Home answer card samples **exactly `#06223F`**, the
   documented solid fill, with the 1 pt white 0.18 border. 100 % of the sampled
   50 × 50 patch is that one colour, so the glass is genuinely gone, not merely
   darker.
2. **Increase Contrast works.** `simctl ui increase_contrast enabled`, read back.
   The `oceanGlass*` surfaces gain the 45 % navy backing and the 1.5 pt white 0.5
   border; the Home answer card fill moves `#194161` → `#0D263E`
   (L 0.0485 → 0.0182), and the map card's accent text goes from failing to
   passing (§7).
3. **Reduce Motion is wired at every app-owned animation.** Set through
   `com.apple.Accessibility/ReduceMotionEnabled`, read back, rebooted. Only three
   explicit animations exist in `Estran/`, and all three read the flag
   (`SpotsView.swift:65`, `SpotSwitcher.swift:51`, `ActivitySegmentedControl.swift:49`).
   No still screenshot can prove the absence of motion; §3.4 records what the run
   does show and what it cannot.
4. **`SpotsView` fails the contrast gate at the default settings** — this is the
   blocking finding of the pass. On the glass card over map tiles the verdict
   badge « Oui » measures **2.86:1** and « Voir le détail » **3.69:1**
   (threshold 4.5:1 for 13 pt text). Both pass as soon as Increase Contrast or
   Reduce Transparency is on, so the defect is that the *default* rendering is
   the worst one.

Everything else is consistency debt: the chip controls bypass `oceanGlass*`, so
they adapt through the system only (§5.1), and the chip label crosses a
low-contrast grey while its selection tint animates (§5.2).

## 2. How each configuration was produced and verified

Every run: `xcodebuild test -project Estran.xcodeproj -scheme Estran
-destination id=6D875634-… -derivedDataPath build/DerivedData
-only-testing:EstranUITests/AccessibilityTourUITests -resultBundlePath
build/a11y/<config>.xcresult`, followed by
`xcrun xcresulttool export attachments`.

`simctl ui` has no options for Reduce Motion or Reduce Transparency (its help
lists only `appearance`, `increase_contrast`, `content_size`), so those two were
written into the simulator's accessibility domain, read back, and made durable
by rebooting the device before the run — `cfprefsd` in the simulator otherwise
keeps the old value.

| Config | Commands | Verification (read back) | Evidence |
|---|---|---|---|
| `baseline` | `simctl ui … appearance light`, `increase_contrast disabled`; RT/RM keys left at `0` | `appearance: light`, `increase_contrast: disabled`, `EnhancedBackgroundContrastEnabled = 0`, `ReduceMotionEnabled = 0` | Home card `#194161`, map card `#2E4895`–`#2C6D65` |
| `increase-contrast` | `simctl ui … increase_contrast enabled`, appearance light, RT/RM `0` | `increase_contrast: enabled` | Home card `#0D263E`, 1.5 pt border visible, map card `#0C2B3F` |
| `reduce-transparency` | `simctl spawn … defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool YES`, reboot | `defaults read … EnhancedBackgroundContrastEnabled` → `1` before **and** after the reboot | Home and map cards sample exactly `#06223F` |
| `reduce-motion` | `defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES`, reboot | `defaults read … ReduceMotionEnabled` → `1` before and after the reboot | §3.4 |
| `dark-increase-contrast` | `simctl ui … appearance dark`, `increase_contrast enabled`, RT/RM `0` | `appearance: dark`, `increase_contrast: enabled` | §3.5 — renders identically to `increase-contrast` |

**Restored to default at the end:** `appearance light`, `increase_contrast
disabled`, `EnhancedBackgroundContrastEnabled = 0`, `ReduceMotionEnabled = 0`,
`content_size large`; the App Group `selectedSpotID` was put back to
`arcachon-eyrac`. All read back after the last run.

Two notes on the run log, for the next person: one `increase-contrast` run
failed to launch the app (`Simulator device failed to launch
com.forgedigitalesolutions.estran`) and succeeded unchanged on retry — no assertion
failed; and an additional dark-appearance baseline was captured before the five
configurations above and is not used, because it duplicates `baseline` (§2.1).

### 2.1 Two facts about the harness that shape the evidence

1. **The app is dark in every configuration.** `RootView.swift:40` applies
   `.preferredColorScheme(.dark)`, so the simulator's Light appearance does not
   reach the app content or the map: `baseline` and `dark-increase-contrast`
   differ only in system chrome, and both maps render the dark tile style. A
   "light appearance" measurement of the glass card therefore does not exist —
   not because it was skipped, but because the app cannot be rendered light.
2. **A spot change always captures a loading card.** `AppModel.select(spot:)`
   (`AppModel.swift:140-145`) clears and reloads, and the tour takes the Spots
   screenshot immediately after the tap. To get a *settled* map card the pass
   pre-seeded the persisted spot (`selectedSpotID = pointe-de-grave` in the App
   Group container) before every run, so the tour's first spot tap is a no-op.
   That is why `baseline-06-spots-pointe-de-grave.png` shows a verdict and
   `baseline-07-spots-arcachon-eyrac.png` shows the spinner: `07` is the real
   transition, 0.9 s after the tap.

### 2.2 Per-setting index

| Setting | Toggled with | Verified by | Screens | Findings |
|---|---|---|---|---|
| Reduce Transparency | `defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool YES` + reboot | read-back before/after reboot, then the card sampling exactly `navyInk` `#06223F` | `reduce-transparency-{01,06,08,12}-…` | none blocking; §5.1 (chips), §5.2 |
| Increase Contrast | `simctl ui … increase_contrast enabled` | `simctl ui … increase_contrast` → `enabled`; card fill `#194161` → `#0D263E`, 1.5 pt border visible | `increase-contrast-{01,06,10,12}-…` | none blocking; §5.1 |
| Reduce Motion | `defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES` + reboot | read-back before/after reboot; final-state frame at the moment of a change; three code sites | `reduce-motion-{01,06,07}-…` | none |
| Dark appearance + Increase Contrast | `simctl ui … appearance dark`, `increase_contrast enabled` | `appearance: dark`, `increase_contrast: enabled`; rendering identical to `increase-contrast` | `dark-increase-contrast-{01,06}-…` | none (see §2.1) |
| Default rendering (the gate itself) | — | pixel sampling of the map card | `baseline-{01,05,06,07,10}-…` | **B1, B2 blocking**; §5.2, §5.3 |

## 3. Screens checked

All 12 tour screens were reviewed in every configuration. The screenshots kept
in `screens/2026-11-11/` are the ones cited below (file names are
`<config>-NN-name.png`).

### 3.1 `baseline` (defaults, light appearance)

| Screen | Observation |
|---|---|
| `baseline-01-home-peche.png` | Glass cards, chips, spot pill and tab bar as designed. Answer card fill `#194161`. |
| `baseline-05-home-baignade.png` | Swimming card: no `Oui`, warning first, level in `swimmingRiskText`. Unchanged by the pass. |
| `baseline-06-spots-pointe-de-grave.png` | **The measured frame.** Settled card with « Oui », window line and « Voir le détail » over the map. |
| `baseline-07-spots-arcachon-eyrac.png` | Transition: card says « Arcachon-Eyrac », map still on Pointe de Grave, chips mid-fade. |
| `baseline-10-detail-spot.png` | Chart card, tile row, activity list: all `oceanGlassCard`. |

`08-alertes` and `09-reglages` were reviewed as well: the Alerts card is glass
and adapts like the others; Réglages is a system `List` (`SettingsView.swift:20`),
so it has no app glass surface to adapt.

### 3.2 `increase-contrast`

| Screen | Observation |
|---|---|
| `increase-contrast-01-home-peche.png` | Cards and tiles darker, 1.5 pt border. Chips darker too, but through the system, not the app border (§5.1). |
| `increase-contrast-06-spots-pointe-de-grave.png` | Card `#0C2B3F` with a strong border. « Oui » 6.60:1, « Voir le détail » 8.98:1. Unselected chip `#162141`, white label 15.8:1. |
| `increase-contrast-10-detail-spot.png` | Chart, tiles and activity list all carry the border. |
| `increase-contrast-12-activite-reglages.png` | Picker rows are `oceanGlassCard`: dark fill + border. Bar buttons (X / ✓) are direct `glassEffect`: dark, **no** app border. |

### 3.3 `reduce-transparency`

| Screen | Observation |
|---|---|
| `reduce-transparency-01-home-peche.png` | Answer card exactly `#06223F`, no refraction, 1 pt border at 0.18. Chips `#0D1526` (system), not `#06223F`. |
| `reduce-transparency-06-spots-pointe-de-grave.png` | Card `#06223F`; the map card is now the most readable of the three states. |
| `reduce-transparency-08-alertes.png` | Alerts card solid `navyInk`; the system `Toggle` keeps its own rendering. |
| `reduce-transparency-12-activite-reglages.png` | Rows solid; bar buttons near-black (system), fill differs from the rows (§5.1). |

### 3.4 `reduce-motion`

The flag is verified in the preference store, and one frame corroborates it:

- `reduce-motion-06-spots-pointe-de-grave.png` is the same layout as `baseline`
  (as intended: Reduce Motion removes motion, never information), and
  `reduce-motion-01-home-peche.png` is the same Home as `baseline` for the same
  reason.
- `reduce-motion-07-spots-arcachon-eyrac.png`: the screenshot is taken
  immediately after the chip tap. In `baseline` the same frame still shows the
  **old** camera (Pointe de Grave). Under Reduce Motion the map is already on
  the **new** region — an unpainted grid with the marker centred — which is what
  `withAnimation(OceanGlass.animation(…, reduceMotion:))` does with `nil`.
  The chips also show no grey crossfade (§5.2), the second observable of the
  flag.

**Limit, stated plainly:** a still image cannot prove that nothing animates
during the 0.45 s selection spring or the tab push. The pass verified (a) the
preference, (b) the three code paths that consume it, and (c) that the two
screens captured immediately after a change show the *final* state rather than
an intermediate one. It did not record video, and it did not measure the
system-owned transitions (tab switch, navigation push), which UIKit/SwiftUI
already honour.

### 3.5 `dark-increase-contrast`

Renders the same app content as `increase-contrast` (§2.1): the map card, the
glass fills and the borders are unchanged — Home `#0D263E` in both, map card
`#0C2B3F` vs `#0D2C3D` — so only the status-bar and system chrome treatment
follow the appearance setting (`dark-increase-contrast-01-home-peche.png`,
`dark-increase-contrast-06-spots-pointe-de-grave.png`).

## 4. View-by-setting table

Source grep over `Estran/` and `EstranWidgets/`:

- `accessibilityReduceTransparency` — 1 read, `GlassStyles.swift:120`.
- `colorSchemeContrast` — 1 read, `GlassStyles.swift:121`.
- `accessibilityReduceMotion` — 3 reads: `SpotsView.swift:15`,
  `SpotSwitcher.swift:19`, `ActivitySegmentedControl.swift:21`.
- `glassEffect` — 3 direct call sites outside the shared modifier:
  `ActivitySegmentedControl.swift:136`, `SpotSwitcher.swift:79`,
  `ActivityPickerView.swift:94`; the shared modifier itself calls it twice
  (`GlassStyles.swift:138, :141`). Plus `buttonStyle(.glass)` at
  `SmallComponents.swift:41`.
- Nothing in `EstranWidgets/` reads any of the four settings (the widgets and the
  Live Activity use opaque backgrounds, not glass).

`●` = reads the setting in app code, `○` = inherits the system behaviour of the
glass/material it uses, `—` = not animated / not applicable.

| View / surface | Source | Reduce Transparency | Increase Contrast | Reduce Motion |
|---|---|---|---|---|
| All `oceanGlassCard` / `oceanGlassCapsule` surfaces | `Theme/GlassStyles.swift:117-164` | ● solid `navyInk` + 1 pt border | ● 45 % navy backing + 1.5 pt border | — |
| `AnswerCard` | `Features/Home/Components/AnswerCard.swift:64` | ● | ● | — |
| `SwimmingAdvisoryCard` | `…/SwimmingAdvisoryCard.swift:63` | ● | ● | — |
| `NextWindowCard` | `…/NextWindowCard.swift:52` | ● | ● | — |
| `ConditionsGrid` tiles | `…/ConditionsGrid.swift:93` | ● | ● | — |
| `TipCard` | `…/TipCard.swift:31` | ● | ● | — |
| `LoadingCard`, `UnavailableCard` | `Features/Home/HomeView.swift:177, :212` | ● | ● | — |
| `TideChartCard` | `Features/SpotDetail/TideChartCard.swift:56` | ● | ● | — |
| `ActivityOverviewList`, detail cards | `Features/SpotDetail/ActivityOverviewList.swift:35`, `SpotDetailView.swift:25, :219, :239` | ● | ● | — |
| `AlertOptInToggle` card, Alerts cards | `Features/Alerts/AlertsView.swift:70, :94` | ● | ● | — |
| `SpotsView` spot card | `Features/Spots/SpotsView.swift:122` | ● | ● | — |
| `ActivityPickerView` rows | `Features/ActivityPicker/ActivityPickerView.swift:162` | ● | ● | — |
| Segmented-control `Menu` label (AX sizes) | `…/ActivitySegmentedControl.swift:90` | ● | ● | — |
| `SpotSwitcher` `Menu` label (AX3+) | `Features/Spots/SpotSwitcher.swift:113` | ● | ● | — |
| **`ActivitySegmentedControl` chips** | `…/ActivitySegmentedControl.swift:136` | ○ system | ○ system | ● `transaction` strip (`:49-53`) |
| **`SpotSwitcher` chips** | `Features/Spots/SpotSwitcher.swift:79` | ○ system | ○ system | ● `.animation(nil, value:)` (`:51-53`) |
| **`ActivityPickerView` bar buttons** | `Features/ActivityPicker/ActivityPickerView.swift:94` | ○ system | ○ system | — |
| **`SpotButton` pill** | `Features/Shared/SmallComponents.swift:41` (`.buttonStyle(.glass)`) | ○ system | ○ system | — |
| `SpotsView` map camera | `Features/Spots/SpotsView.swift:15, :61-72` | — | — | ● `OceanGlass.animation` |
| Tab bar, nav bars, `Toggle`, `Menu` popovers | system | ○ | ○ | ○ |
| Widgets / Live Activity | `EstranWidgets/**` | — (opaque `containerBackground`, not glass) | — | — |

`accessibilityDifferentiateWithoutColor` is read nowhere; the palette is never
the only signal (every state carries a word and an SF Symbol), so this is a
non-blocking observation rather than a defect.

## 5. Findings — non-blocking

### 5.1 The four chip/button controls bypass `oceanGlass*`, so the app-owned part of Reduce Transparency and Increase Contrast never reaches them

`ActivitySegmentedControl.swift:136`, `SpotSwitcher.swift:79` and
`ActivityPickerView.swift:94` call `.glassEffect` directly instead of
`oceanGlassCapsule()`; `SpotButton` uses `.buttonStyle(.glass)`. The result, in
the `reduce-transparency` run:

| Surface | Fill under Reduce Transparency | Fill of the app cards |
|---|---|---|
| Home chips, spot chips, picker bar buttons | `#0D1526` (system glass, opaque) | `#06223F` (`navyInk`) |

The system does honour both settings for `glassEffect`, so contrast is safe
(the chip label measures 18.22:1 under Reduce Transparency and 15.81:1 under
Increase Contrast), but the controls look like a different material family from
the cards they sit in, and they never get the 1.5 pt Increase Contrast border
the cards get. In the `increase-contrast` run the card border is clearly visible
while the chips have only their specular edge.

**Fix.** Give the chips the same modifier they already have available:
`.oceanGlassCapsule()` on the chip label, with the selected tint carried by the
`Glass` value. Two constraints from the sources: the chips live in a
`GlassEffectContainer` that must keep merging (the modifier keeps `glassEffect`
in the normal branch, so merging is preserved), and the selected chip must keep
its white pill, so `oceanGlassCapsule(tinting:)` would need a tint parameter, or
the selected chip keeps the direct `.glassEffect` and only the unselected ones
switch.

### 5.2 A chip label crosses ~1.3:1 grey while its selection tint animates

`SpotSwitcher.swift:51-53` animates the whole container on `selection.id`, and
`SpotSwitcher.swift:74` interpolates the label between `ink` and `white` with
it. For roughly half a second after a spot change, the deselected chip renders
grey text on light glass. Measured on
`screens/2026-11-11/baseline-07-spots-arcachon-eyrac.png`, left chip, region
`x 150…470, y 2185…2278`: label core `#B5BEC8` (L 0.5082) on chip glass
`#80B1AE` / `#84ABAE` (L 0.391 / 0.371) → **1.27–1.33:1**.

It is transient (the settled frame, `baseline-06-…`, is 7.2–7.5:1) so it is
non-blocking, but it is the frame a screenshot or a screen recording is most
likely to catch, and it is exactly the frame a low-vision user sees while
switching spots.

**Fix.** Animate the glass only: apply `.animation(nil, value: selection.id)` to
the label (or move the colour change out of the animated transaction) so the
text snaps to its final colour while the fill cross-fades. The same pattern
already exists in `ActivitySegmentedControl.swift:49-53`.

### 5.3 The map card has no settled state after a spot change

`AppModel.select(spot:)` (`AppModel.swift:140-145`) clears the store before
reloading, so after every spot switch the card shows the spot name and a
spinner for at least a second (`baseline-07-spots-arcachon-eyrac.png` in every
run) while the camera is already moving. It is correct by the no-stale-state
rule (`DESIGN_REFERENCE.md` §2.1), but it means the verdict — the card's only
accessibility-critical text — is absent at the exact moment the map moves. No
change suggested; recorded so the next audit does not read it as a capture
artefact.

## 6. Findings — blocking

### B1. `SpotsView` verdict badge « Oui » is 2.86:1 over the map glass

| | |
|---|---|
| Evidence | `screens/2026-11-11/baseline-06-spots-pointe-de-grave.png`, region `x 60…280, y 1786…1848` (3× scale) |
| Foreground | `OceanPalette.oui` `#34C759` — measured core pixel `#34C759` |
| Background | glass over the green map patch, modal `#2B686E`, L 0.1154 |
| Ratio | **2.86:1** (needs 4.5:1 at 13 pt semibold) |
| Source | `Features/Spots/SpotsView.swift:160` → `SmallComponents.swift:51-57` → `VerdictState.swift:51-57` |
| Responsible line | `VerdictState.swift:53` — `case .go: OceanPalette.oui` |

The `.noGo` branch already returns the lifted token (`nonOnGlass`), the `.go`
branch does not. That asymmetry is the bug: `badgeColor` is documented as "the
colour for small text on glass" (`VerdictState.swift:49-50`) but returns the
vivid `oui` used for the 76 pt badge.

**Fix, smallest first.**
1. `case .go: OceanPalette.ouiOnGlass` (`#7BE495`). On the same backdrop it
   measures **3.84:1** — better, still short of 4.5:1 on the brightest patch of
   the map card.
2. Give the map card a permanent dark scrim. The Increase Contrast path already
   proves the number: with the 45 % `navyInk` backing the card is `#0C2B3F` and
   the same label measures **6.60:1**. Reusing that backing unconditionally for
   `SpotsView` only (`SpotDetailView` and Home do not sit on a map) is the
   smallest change that fixes every accent on the card at once, including B2
   and the `nonOnGlass` / `sand` variants.
3. A stronger glass fill is *not* a fix: the card is already lighter than the
   Home card (`#2E4895`–`#2C6D65` vs `#194161`), so the direction is wrong.

### B2. « Voir le détail » is 3.69:1 over the map glass

| | |
|---|---|
| Evidence | same screenshot, region `x 60…380, y 1976…2038` |
| Foreground | `OceanPalette.turquoiseOnGlass` `#5DDED4` — measured `#5DDED4` |
| Background | glass over the green patch, modal `#2C6D65`, L 0.1241 |
| Ratio | **3.69:1** (needs 4.5:1 at 13 pt semibold) |
| Source | `Features/Spots/SpotsView.swift:113` and the card at `:122` |

The token was calibrated against the Home card (L 0.0485, where it measures
6.53:1); the map card is two to three times brighter.

**Fix.** Either the same scrim as B1 (→ 8.98:1, measured in the
`increase-contrast` run), or make the label `white` and keep the turquoise on
the chevron: white is 6.03:1 on the same patch, and the chevron is a non-text
icon at 3:1, which `turquoiseOnGlass` meets (3.69:1). The second option costs no
new asset and no new colour.

### B3. Why these are blocking rather than cosmetic

The map card is the only surface where the app shows a verdict next to a spot
name, and it is the frame the user sees when choosing where to go. The two
failing strings are the verdict and the only action on the card. Both pass under
Increase Contrast and under Reduce Transparency, i.e. only for users who
already turned an accessibility setting on — the inverse of what the gate
requires.

## 7. `SpotsView` glass over map tiles — measurements

**Method.** PNG region sampling on the exported 3× screenshots (`1206 × 2622`),
pure-Python decoder, WCAG 2.1 relative luminance, no compositing model: the
measured pixel *is* the rendered colour. For each text line the local backdrop
was taken from 8 px strips immediately above and below the glyph band (modal
colour of each strip, worst of the two), which avoids the dithering of the glass
over the map raster. Text colours were read from the brightest glyph pixel and
matched to the palette token.

### 7.1 Settled state, default settings (`baseline-06-spots-pointe-de-grave.png`)

| Element | Token (source) | Measured text | Local backdrop | Ratio | Threshold | Verdict |
|---|---|---|---|---|---|---|
| « Pointe de Grave » (17 semibold) | `white` `SpotsView.swift:77-79` | `#FFFFFF` | `#2F4895` L 0.074 | **8.46** | 4.5 | PASS |
| « Oui » (13 semibold) | `oui` `VerdictState.swift:53` | `#34C759` | `#2B686E` L 0.115 | **2.86** | 4.5 | **FAIL** |
| « 19 h 28 à 20 h 28 » (13) | `white 85 %` `SpotsView.swift:95` | `#E0E9E9` | `#2E696C` L 0.118 | **4.97** | 4.5 | PASS (marginal) |
| « Voir le détail » (13 semibold) | `turquoiseOnGlass` `SpotsView.swift:113` | `#5DDED4` | `#2C6D65` L 0.124 | **3.69** | 4.5 | **FAIL** |
| Unselected chip « Arcachon-Eyrac » (13) | `white` `SpotSwitcher.swift:74` | `#FFFFFF` | `#3351AC` L 0.096 | **7.21** | 4.5 | PASS |
| Selected pill « Pointe de Grave » (13) | `ink` on white pill `SpotSwitcher.swift:59, :74` | `#06223F` | `#FFFFFF` L 1.000 | **16.05** | 4.5 | PASS |
| Card as a whole | — | — | `#2E4895`–`#2C6D65` | — | — | — |

### 7.2 Same card, other configurations

| Element | baseline | increase-contrast | reduce-transparency |
|---|---|---|---|
| Card backdrop (sampled) | `#2E4895`–`#2C6D65`, L 0.074–0.124 | `#0C2B3F`–`#11264B`, L 0.020–0.022 | `#06223F`, L 0.0154 |
| « Pointe de Grave » white | 8.46 | 14.65 | 16.05 |
| « Oui » `oui` | **2.86 FAIL** | 6.60 | 7.23 |
| Window line white 85 % | 4.97 (marginal) | 10.93 | 11.87 |
| « Voir le détail » `turquoiseOnGlass` | **3.69 FAIL** | 8.98 | 9.83 |
| Unselected chip / selected pill | 7.21 / 16.05 | 15.81 / 15.41 | 18.22 / 14.74 |

`dark-increase-contrast` measures the same as `increase-contrast`
(15.81 / 15.41), which is the second confirmation that the forced dark scheme
makes the two configurations render alike.

### 7.3 What the same card's other tokens would measure

Ratios of every card token against the *brightest* measured backdrop
(`#2C6D65`, L 0.1241, the green map patch the link sits on). WCAG text
thresholds are 4.5:1 (13–17 pt) and 3:1 (76 pt / icons).

| Token | Ratio on the map card | On the Home card (`#194161`, measured) | Verdict on the map card |
|---|---|---|---|
| `white` | 6.03 | 10.66 | PASS |
| `white` 85 % | 4.87 | 8.16 | PASS (marginal) |
| `white` 70 % (swimming disclaimer) | 3.87 | 6.13 | **FAIL** |
| `sand` (blockers, « Créneaux indisponibles ») | 4.75 | 8.40 | PASS (marginal) |
| `oui` | 2.72 | 4.80 | **FAIL** |
| `ouiOnGlass` | 3.84 | 6.79 | **FAIL** |
| `nonOnGlass` | 3.71 | 6.56 | **FAIL** |
| `turquoiseOnGlass` | 3.69 | 6.53 | **FAIL** |

So on the map card the failing set is every accent at small size, plus the
70 % white disclaimer that `SpotsView.swift:156` renders on the swimming state.
The `sand` and white families survive only marginally.

### 7.4 The card is lighter than the audited glass model, not darker

`contrast-audit.md` §2.4 modelled app glass at 15 % white over the gradient
(`#2F5A7A`, L 0.0932) and §10 asked for one sampled card. Measured on the same
run: the Home answer card is `#194161` (L 0.0485) — **darker** than the model, so
the Home pairs of that audit are conservative and its remediation tokens are
correct there. The map card is the opposite: `#2E4895`–`#2C6D65`
(L 0.074–0.124), **lighter** than the model, because it samples the map raster
instead of the gradient. Table B of the contrast audit must not be reused for
`SpotsView`; §7 above is the replacement.

## 8. What this pass did not complete, and why

| Item | Status |
|---|---|
| Reduce Motion proof by video | Not done. Toggled and read back, code paths audited, two frames corroborate; a still image cannot show the absence of motion. |
| A light-appearance measurement of the glass | Impossible in this build: `.preferredColorScheme(.dark)` (`RootView.swift:40`) forces dark app content and dark map tiles in both appearances. |
| Increase Contrast + Reduce Transparency together | Not requested; `GlassAppearance` defines the combined look (`both on` → solid fill + 1.5 pt border) but it was not captured. |
| Widgets / Live Activity | Out of scope: they use opaque `containerBackground` / `activityBackgroundTint`, no glass surface, so none of the four settings has a surface to change. |
| VoiceOver, Bold Text, Button Shapes, Differentiate Without Colour | Not part of this pass (VoiceOver has its own audit; Bold Text and Button Shapes are M6). |
| Real device | Simulator only, as instructed. Glass rendering on device may differ; the measured numbers are the simulator's. |

## 9. Reproduction

```sh
cd /Volumes/dock/dev/orca/estran
UDID=6D875634-293F-4D8B-8227-B8DEA7CAC589

# default settings
xcrun simctl ui $UDID appearance light
xcrun simctl ui $UDID increase_contrast disabled
xcrun simctl spawn $UDID defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool NO
xcrun simctl spawn $UDID defaults write com.apple.Accessibility ReduceMotionEnabled -bool NO

xcodebuild test -project Estran.xcodeproj -scheme Estran -destination id=$UDID \
  -derivedDataPath build/DerivedData \
  -only-testing:EstranUITests/AccessibilityTourUITests \
  -resultBundlePath build/a11y/baseline.xcresult
xcrun xcresulttool export attachments --path build/a11y/baseline.xcresult \
  --output-path build/a11y/baseline/

# a settled Spots card: pre-seed the persisted spot, reboot, then run
plutil -replace selectedSpotID -string pointe-de-grave \
  ~/Library/Developer/CoreSimulator/Devices/$UDID/data/Containers/Shared/AppGroup/*/Library/Preferences/group.com.forgedigitalesolutions.estran.plist
xcrun simctl shutdown $UDID && xcrun simctl boot $UDID
```

The sampler used for every number in §7 is `build/a11y/pngstat.py` (scratch,
git-ignored): pure-Python PNG decode, WCAG luminance, modal-colour regions.
