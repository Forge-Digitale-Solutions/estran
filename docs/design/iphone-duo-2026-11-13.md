# iPhone Duo support — 2026-11-13

Estran must run « made for iPhone Duo »: fill the unfolded display, keep the
phone layout on the cover display, and still pass App Store upload. This note
records what changed, which SDK facts back it, and what could **not** be
verified on this machine.

Internal technical doc (English); the UI copy stays French.

---

## 1. What the Duo changes

| Display | Pixels | Points (3×) | Shape |
|---|---|---|---|
| Inner, unfolded | 2853 × 2007 | **951 × 669** | regular width, compact height |
| Outer, folded | 1398 × 2034 | **466 × 678** | phone width (compact) |

The app was portrait-only with `UIRequiresFullScreen` = `true`. On a window it
cannot fill, iOS letterboxes it: a centred phone column with black sides, and —
as the owner saw on day one — a `TabView` that could come up without its tab
bar. Both are symptoms of the same cause: the app declared that it refuses any
window that is not the phone rectangle.

Point sizes are derived from the 3× scale and are the sizes the render tests
use. The App Store screenshots the coordinator takes later must come from the
real Duo displays; this branch does not contain them.

## 2. Orientation

### Info.plist (`Estran/Info.plist`)

- **`UIRequiresFullScreen` removed.** The key is deprecated since iOS 26 —
  the built app warned on every build — and it is what produced the letterboxed
  column on the unfolded display.
- **All four orientations declared**: portrait, portrait upside down, landscape
  left, landscape right. The earlier rejection was « all orientations or full
  screen »; with the full-screen flag gone, all orientations are declared so the
  upload condition holds and the Duo can be held either way.

### The iOS 27 way to keep a lock (verified, not used)

The SDK does offer a scene-level override:

```objc
// UIKit/UIWindowScene.h (iPhoneOS27.2.sdk)
- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindowScene:
    (UIWindowScene *)windowScene API_AVAILABLE(ios(27.0), visionos(27.0));
```

Its `UIApplicationDelegate` equivalent is deprecated in iOS 27 with the message
« Use UIWindowSceneDelegate.supportedInterfaceOrientations(for:) instead ».

**Decision: no runtime lock.** A `UIWindowSceneDelegate` in a SwiftUI app means
handing scene configuration to UIKit, and the lock would buy nothing: the
landscape iPhone window is the same wide shape the Duo unfolded produces, and
the adaptive layout handles it (below). One rule, one behaviour, less code.

## 3. The layout rule

`Estran/App/OceanLayout.swift` is the single decision point. It asks about the
**window**, never about the device model:

```swift
usesTwoColumns(width:sizeClass:dynamicTypeSize:)
```

| Signal | Value | Result |
|---|---|---|
| width ≥ 700 pt | 951 (Duo unfolded), 956 (Pro Max landscape) | two columns |
| width < 700 pt | 440 (Pro Max portrait), 466 (Duo folded), 402 (Figma) | one column |
| width unknown (first pass, `ImageRenderer`) | falls back to `horizontalSizeClass == .regular` | deterministic in tests |
| `dynamicTypeSize.isAccessibilitySize` | AX1…AX5 | **always one column**, capped |

Two constants keep the wide layout readable:

- `readableContentWidth = 760 pt` — a 951 pt line would run ~120 characters;
  the content column is centred instead.
- side column 300–380 pt (ideal 340) with a 24 pt gap, so the leading column
  keeps ≥ 396 pt for the answer card and the five activity chips.

**Dynamic Type wins over width** on purpose. `DESIGN_REFERENCE.md` §2.1 makes
AX5 a release gate and the reflow ladder stacks horizontal pairs; a two-column
split at AX5 would hand each column less room than the phone layout it is meant
to improve. At AX5 the unfolded display shows one column capped at 760 pt.

Each screen reads its width from a `GeometryReader` that wraps the scroll view —
not from `onGeometryChange` updating `@State`. The state write happens during
layout, and `ImageRenderer` (the render tests) cannot run that: it crashes with
`Fatal error: no current update to enqueue action to`. The `GeometryReader`
form is read-only during layout, so both the app and the renders work.

## 4. Screen by screen

| Screen | One column (phone, Duo folded) | Two columns (Duo unfolded) |
|---|---|---|
| **01 Home** | Figma order: header, title, activity bar, answer, next window, conditions, tip | leading: activity bar + answer; trailing 340 pt: next window + conditions (2×2 tiles) + tip |
| **05 Spots** | map edge to edge, card + switcher pinned bottom | same map, card + switcher in a 340 pt column at the bottom-trailing corner |
| **02 Spot detail** | chart, metrics, activity list, alert opt-in | chart at the full 760 pt; leading: metrics + alert opt-in; trailing 340 pt: the five activity rows |
| **04 Alertes / 06 Réglages / 03 picker** | unchanged | same single column, capped at 760 pt and centred |

VoiceOver order is unchanged because it follows source order: Home reads answer
then next window then conditions; the detail reads chart, metrics, toggle, then
activities. Nothing was reordered for the layout.

Every accessibility gate is preserved: AX5 reflow (above), Reduce
Transparency/Contrast (the glass surfaces are untouched), Reduce Motion (no new
animation; the two-column change is not animated), and 44 pt targets (no control
resized).

## 5. Tab bar

`TabView` keeps the four `Tab`s — « Maintenant », « Spots », « Alertes »,
« Réglages » — with `.tabBarMinimizeBehavior` and the 27.1 toolbar compression
already in place.

`TabViewStyle.sidebarAdaptable` is verified in the SDK (iOS 18+), and it is the
reason it was considered. It is **not** adopted: on iPhone it would trade the
Liquid Glass bar the design reference specifies (`DESIGN_REFERENCE.md` §3.1,
§6) for a sidebar, and the Duo simulator is not available to check the result.
The bottom bar already adapts to the wider window by itself and keeps the four
labels the UI tests query.

## 6. Widgets and Live Activity

No change. Widget families are chosen by the system per widget, not per display
size: `GoWidget` still declares `.systemSmall/.systemMedium/.systemLarge` +
the three Lock Screen accessories, `ConditionsWidget` `.systemMedium`, the
Control Center widget and the Live Activity are unchanged. Nothing in those
views reads a device width, so a wider phone screen changes nothing for them.
`liveActivity` layouts are already validated at 370/393 pt
(`LiveActivityRenderTests`).

## 7. Tests

| Test | What it pins | Runs where |
|---|---|---|
| `OceanLayoutTests` | the width/size-class/Dynamic Type matrix, the 700 pt boundary, the readable cap | anywhere (`swift test` style unit tests) |
| `DuoLayoutRenderTests` | Home/Spots/SpotDetail at 951 × 669 and 466 × 678 with injected size classes, PNGs in `Documents/duo-renders` | **opt-in** (needs a simulator, see below) |
| `DuoLayoutUITests` | portrait → landscape on a real window: four tab labels, the answer, and the next-window card moving beside the answer card | simulator, one device |

Product tests remain untouched: `./scripts/check-linux.sh` (250 tests) and the
hosted `EstranTests` / `EstranUITests` suites.

Render tests are opt-in because a whole-screen `ImageRenderer` needs a live
simulator process:

```sh
TEST_RUNNER_ESTRAN_DUO_RENDERS=1 xcodebuild test \
  -project Estran.xcodeproj -derivedDataPath build/DerivedData \
  -scheme Estran -destination 'id=<simulator-udid>' \
  -only-testing:EstranTests/DuoLayoutRenderTests
```

## 8. What was not verified, and why

- **No Duo simulator.** The iOS 27.2 Duo runtime sent the simulator's
  `PosterBoard` into a crash loop (Apple's Kaleidoscope wallpaper extension, not
  Estran: it crashed before the app was installed, and the widget extension is
  not involved). It froze the owner's Mac twice. The simulator was deleted and
  the branch was finished without booting any simulator: `xcodebuild
  build-for-testing` against `generic/platform=iOS Simulator`, plus
  `check-linux.sh`, lint and format.
- **The wide layouts are therefore compile- and logic-verified, not
  screen-verified.** The images that prove them must come from the real Duo:
  the `#Preview("Duo déplié — 951 × 669 pt")` in each of the three screens, the
  opt-in render tests, or the coordinator's device pass.
- **Fold state cannot be driven from the CLI** (`simctl` has no fold command;
  the two displays are separate screens and the state belongs to the simulator's
  device UI). This never became a blocker: the folded display is the phone
  layout, which the existing suites already cover.

## 9. Files

- `Estran/App/OceanLayout.swift` — the rule and the readable cap.
- `Estran/Features/Home/HomeView.swift`, `Components/ConditionsGrid.swift`,
  `Components/HomeStateCards.swift` (the three non-verdict cards, moved out of
  `HomeView`).
- `Estran/Features/Spots/SpotsView.swift`.
- `Estran/Features/SpotDetail/SpotDetailView.swift`.
- `Estran/Features/Alerts/AlertsView.swift`,
  `Estran/Features/Settings/SettingsView.swift`,
  `Estran/Features/ActivityPicker/ActivityPickerView.swift` — readable cap.
- `Estran/Info.plist` — orientations.
