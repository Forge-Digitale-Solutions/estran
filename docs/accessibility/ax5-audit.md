# M3 AX5 accessibility audit (simulator evidence)

Evidence tour: `EstranUITests/AccessibilityTourUITests.swift` — nine screenshots plus tap-target text attachments per run.

**Device:** iPhone 18 Pro (iOS 27.0) · **Build:** Debug · **Date:** 2026-10-28

## Commands

```sh
# Register UI test in generated project (after adding the test file)
cd /Users/anthony/orca/estran && xcodegen generate

# Reset persisted spot (optional; default catalog spot is Pointe de Grave)
xcrun simctl spawn "iPhone 18 Pro" defaults delete group.com.forgedigitalesolutions.estran selectedSpotID

# Medium (default Dynamic Type)
xcrun simctl ui "iPhone 18 Pro" content_size medium
xcodebuild -project Estran.xcodeproj -scheme Estran -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:EstranUITests/AccessibilityTourUITests test \
  -resultBundlePath build/ax5/medium.xcresult

# AX5 (accessibility extra-extra-extra-large)
xcrun simctl ui "iPhone 18 Pro" content_size accessibility-extra-extra-extra-large
xcodebuild -project Estran.xcodeproj -scheme Estran -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:EstranUITests/AccessibilityTourUITests test \
  -resultBundlePath build/ax5/ax5.xcresult

# Restore simulator text size
xcrun simctl ui "iPhone 18 Pro" content_size medium

# Export attachments (screenshots + tap-target reports)
xcrun xcresulttool export attachments --path build/ax5/medium.xcresult --output-path build/ax5/medium/
xcrun xcresulttool export attachments --path build/ax5/ax5.xcresult --output-path build/ax5/ax5/
# Readable copies: build/ax5/{medium,ax5}/export/*.png and tap-targets-*.txt
```

**Result bundles:** `build/ax5/medium.xcresult`, `build/ax5/ax5.xcresult`  
**Screenshots (readable):** `build/ax5/medium/export/01-home-peche.png` … `09-reglages.png`, same names under `build/ax5/ax5/export/`

**Tap-target measurement:** `XCUIElement.frame` on `app.buttons`, `app.tabBars.buttons`, `app.switches`, and `app.links` (see attachments `tap-targets-*.txt`).

## Summary table

Legend: **PASS** / **FAIL** per criterion on the captured frame only (screens not toured are not marked PASS).

| Screen | Text size | No clipped / truncated meaningful text | No fixed-height text container | Horizontal pairs reflow | Tap targets ≥ 44×44 pt | No `.lineLimit(1)` on meaningful copy | Activity picker usable (Menu at AX) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Home — Pêche à pied | medium | PASS | PASS | PASS (2×2 grid) | PASS (chips ≥ 44 pt tall; see `tap-targets-after-launch.txt`) | PASS (no `lineLimit` in app sources) | n/a (chips) |
| Home — Surf | medium | PASS | PASS | PASS | PASS | PASS | n/a |
| Home — Bateau | medium | PASS | PASS | PASS | PASS | PASS | n/a |
| Home — Balade | medium | PASS | PASS | PASS | PASS | PASS | n/a |
| Home — Baignade | medium | PASS | PASS | PASS | PASS | PASS | n/a |
| Spots — Pointe de Grave | medium | PASS | PASS | n/a | PASS | PASS | n/a |
| Spots — Arcachon-Eyrac | medium | PASS | PASS | n/a | PASS | PASS | n/a |
| Alertes | medium | PASS | PASS | n/a | PASS (tab bar; toggle row is one combined target) | PASS | n/a |
| Réglages | medium | PASS | PASS | n/a | PASS | PASS | n/a |
| Home — Pêche à pied | AX5 | **FAIL** — answer/reason lines run under the tab bar on the captured frame (`build/ax5/ax5/export/01-home-peche.png`); ScrollView exists but above-the-fold overlap remains visible | PASS | PASS (single-column tiles when scrolled) | PASS (`tap-targets-after-launch.txt`) | PASS | **PASS** — `Activité` menu + item buttons (tour path) |
| Home — Surf | AX5 | **FAIL** — same tab-bar overlap pattern on capture (`02-home-surf.png`) | PASS | PASS | PASS | PASS | **PASS** |
| Home — Bateau | AX5 | **FAIL** — same pattern (`03-home-bateau.png`) | PASS | PASS | PASS | PASS | **PASS** |
| Home — Balade | AX5 | **FAIL** — same pattern (`04-home-balade.png`) | PASS | PASS | PASS | PASS | **PASS** |
| Home — Baignade | AX5 | **FAIL** — warning copy truncated/obscured at bottom (`05-home-baignade.png`; `SwimmingAdvisoryCard` warning block) | PASS | PASS | PASS | PASS | **PASS** |
| Spots — Pointe de Grave | AX5 | PASS on capture (`06-spots-pointe-de-grave.png`; tour selects **Surf** on Home first so the switcher stays on-screen) | PASS | n/a | **FAIL** — MapKit attribution link `Mentions légales` 81.3×**10.7** pt (`tap-targets-spots-pointe-de-grave.txt`; system map chrome, not app SwiftUI) | PASS | n/a — `Choisir un spot` menu (`SpotSwitcher` ≥ accessibility3) |
| Spots — Arcachon-Eyrac | AX5 | PASS on capture (`07-spots-arcachon-eyrac.png`) | PASS | n/a | **FAIL** — same MapKit `Mentions légales` link (`tap-targets-spots-arcachon-eyrac.txt`) | PASS | n/a |
| Alertes | AX5 | PASS on capture (`08-alertes.png`) | PASS | n/a | **FAIL** — unnamed control **63.0×28.0** pt beside the toggle row (`tap-targets-alertes.txt`; UISwitch chrome in `AlertsView.swift:68`) | PASS | n/a |
| Réglages | AX5 | PASS on capture (`09-reglages.png`) | PASS | n/a | PASS (`tap-targets-reglages.txt`) | PASS | n/a |

## Suspected issues (file:line)

| Finding | Evidence | Location |
| --- | --- | --- |
| AX5 Home content visually competes with the tab bar before scrolling | `build/ax5/ax5/export/01-home-peche.png`, `05-home-baignade.png` | `Estran/Features/Home/HomeView.swift:14-51` (ScrollView padding may be insufficient at AX5) |
| Spots tab has no `ScrollView`; with a tall activity card the spot menu can sit below the fold (UI test had to pick Surf before opening Spots at AX5) | Failed run before tour tweak (`build/ax5/ax5-test.log` ~L278-324); layout risk | `Estran/Features/Spots/SpotsView.swift:16-55` |
| Toggle switch accessibility frame below 44×44 pt at AX5 | `build/ax5/ax5/export/tap-targets-alertes.txt` | `Estran/Features/Alerts/AlertsView.swift:68-81` |
| MapKit legal link below 44×44 pt (system control) | `build/ax5/ax5/export/tap-targets-spots-pointe-de-grave.txt` | Map attribution on `SpotsView` MapKit surface |

## Static checks (all captured screens)

- **`.lineLimit(1)` on meaningful strings:** `rg 'lineLimit' Estran/` → no matches → **PASS** for in-app SwiftUI.
- **Fixed `.frame(height:)` on text containers:** `rg 'frame\\(height:' Estran/` → no matches → **PASS**.
- **Horizontal reflow:** `ConditionsGrid` switches to one column when `dynamicTypeSize.isAccessibilitySize` (`Estran/Features/Home/Components/ConditionsGrid.swift:14-22`) → **PASS** where the grid is shown.

## Test runs

| Text size | `xcodebuild` exit | xcresult |
| --- | --- | --- |
| medium | 0 | `build/ax5/medium.xcresult` |
| AX5 | 0 | `build/ax5/ax5.xcresult` |

## Lead review and remediation (2026-10-28, after this audit)

The tour was re-run against the corrected build. Two defects in the tour itself
were fixed before the numbers below were trusted:

- at AX5 the activity `Menu` sat below the fold and the test tapped an
  off-screen coordinate; `openMenu` now swipes it into view first;
- screenshots were taken mid-animation, so the previous chip looked selected;
  the tour now waits for the layout and scrolls Home back to its top.

Rows whose verdict changes:

| Row | Audit verdict | After remediation |
|---|---|---|
| Home at AX5 — clipped text | **FAIL** | **PASS on the frame**; content still scrolls under the floating tab bar, which is the system behaviour, not clipping. The new capture also exposed a real defect the audit's build did not have: the spot pill was wider than the screen at AX5. The header row now stacks (pill, then badge), and the pill wraps instead of overflowing. |
| Spots at AX5 — switcher below the fold | risk recorded | **PASS** — the switcher is on screen in `06-spots-pointe-de-grave.png` of the re-run; the tour no longer has to shorten the Home card first. |
| Alertes at AX5 — unnamed 63 × 28 pt control | **FAIL** | **NOT AN APP CONTROL.** It is the `UISwitch` thumb reported separately from its row; the row itself is one combined target above 44 pt. No app-side fix without replacing the native switch, which the design does not ask for. |
| Spots — MapKit `Mentions légales` link 81.3 × 10.7 pt | **FAIL** | **NOT APP-FIXABLE.** System map attribution; Apple sets the hit area. Recorded as an accepted platform limitation. |

Static checks re-run on the current tree: `rg 'frame\(height:|lineLimit' Estran/`
returns nothing outside the two documented widget cases; `ConditionsGrid` now
degrades 4 → 2 → 1 column instead of 2 → 1.
