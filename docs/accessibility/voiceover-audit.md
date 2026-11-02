# Estran — VoiceOver and Dynamic Type audit (static, M3 gate)

- **Date:** 2026-10-28
- **Branch:** `dev`, HEAD `4ae8731`, **uncommitted Lead changes present** (working tree read as-is)
- **Scope:** every SwiftUI view under `Estran/Features`, `Estran/App`, `Estran/Theme`, and the
  widget / Live Activity views under `EstranWidgets`, plus the presentation models they read
  (`SwimmingAdvisory`, `SwimmingRiskLevel`, `VerdictState`).
- **Method:** source reading only. No `xcodebuild`, no simulator, no device, no VoiceOver run.
- **Reference:** `worksplit.md` §6 M3 (VoiceOver and Dynamic Type bullets), `DESIGN_REFERENCE.md`
  §2.1 (Dynamic Type) and §6.1 (`SpotSwitcher`), `AGENTS.md` invariants 1–4.

> **This document is not a VoiceOver pass.** The M3 gate needs a real device pass
> (`worksplit.md` §6, M6 re-verification). What follows is the code-level evidence that a
> device pass can be built on, and the exact places where the code already contradicts the
> checklist.

## 1. How to read the statuses

| Status | Meaning |
|---|---|
| **PASS** | The source contains the modifier, string or layout the requirement asks for, at the cited line. |
| **FAIL** | The source contradicts the requirement, or the required information is absent from the element VoiceOver reads. |
| **NOT VERIFIABLE** | The requirement is about runtime output, system-rendered UI, or a view that does not exist yet. Cannot be settled from source. |

Line numbers refer to the working tree as read on 2026-10-28; the tree was dirty, so they will
drift once the Lead's pending changes land.

## 2. Summary

| # | M3 requirement | Status |
|---|---|---|
| 1 | Answer card is one element whose label says everything the card displays, tide detail included | **FAIL** (F1) |
| 2 | Every verdict / level carries text **and** an icon (colour is never the only signal) | **FAIL** (F2, F3) |
| 3 | Decorative SF Symbols are `.accessibilityHidden(true)` | PASS (4 low-risk omissions, O1) |
| 4 | The tide chart exposes its next event as an accessibility value | **NOT VERIFIABLE** — no chart exists (O5) |
| 5 | `SpotSwitcher` announces the selected spot and what activating a chip does | PASS (device check required) |
| 6 | The activity picker announces selection **and** unavailable state | **FAIL** (F4, menu path only) |
| 7 | No `.lineLimit(1)` on a meaningful string (compact Dynamic Island spot name is the exception) | PASS (one adjacent risk, O2) |
| 8 | No `.dynamicTypeSize(...)` clamp without a written justification in `DESIGN_REFERENCE.md` §2.1 | PASS |
| 9 | No fixed height on a text container; `fixedSize` preserved on meaningful text | PASS (widget / Live Activity gaps in O2) |
| 10 | Every tappable control is ≥ 44 × 44 pt in code | **FAIL** (F5, one control) |
| 11 | French copy is tutoiement; no « Oui » for swimming on any surface | PASS in the app, **NOT VERIFIABLE** for widget / Live Activity (O6) |
| 12 | Permanent swimming warning + « L'app estime les courants de marée… » are part of the VoiceOver element | **FAIL** (F6, expanded Dynamic Island) |

Five requirements fail in code, one is not verifiable because the view does not exist, and one
is only half-verifiable because the widget data path is not wired yet. The rest hold, with the
runtime checks listed in §6 still owed.

## 3. Checklist, item by item

### 3.1 Answer card — one element, label covers the card — **FAIL**

**What the card draws** (`Estran/Features/Home/Components/AnswerCard.swift`):

| Element | Line |
|---|---|
| Overline « BON MOMENT POUR SORTIR ? » | `:25-28` |
| Verdict icon + giant word | `:30-40` |
| Reason line `decision.reason` | `:42-45` |
| Tide detail line (`conditions.tide.next`) | `:47-52`, built at `:81-83` |

**Evidence for the element itself — PASS.** `:57-58` collapses the card to a single element and
replaces its label:

```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(accessibilitySentence)
```

**Evidence for the tide detail line — PASS.** `accessibilitySentence` (`:86-104`) appends
`detail` in all three branches (`:90-92`, `:96-98`, `:101-103`), and `detail` is the tide event
line « Marée basse à 14 h 12 » (`:81-83`). The M3 requirement of `worksplit.md:134` is met for
that line.

**Evidence for parity — FAIL.** The `.go` branch (`:88-93`) speaks a fixed paraphrase and
**drops the reason line the card displays**:

```swift
case .go:
    var sentence = "Oui, \(activity.displayName), conditions réunies."
```

`decision.reason` is rendered at `:42-45` but never read for `.go`; `.noGo` (`:94-99`) does read
it. Today `DecisionReason.text` returns « C'est bon pour la pêche à pied. » for a go decision
(`Packages/EstranCore/Sources/EstranCore/Domain/DecisionEngine/DecisionReason.swift:9-11`), so
the meaning survives — the spoken and visible strings simply differ. That tolerance ends at M4,
when the reason becomes a generated sentence: the card would then display one text and speak
another. See **F1**.

**Note, not a failure:** the overline « BON MOMENT POUR SORTIR ? » is not spoken. It is the
screen's question, repeated as the card's eyebrow; adding it would make every visit longer
without adding information.

### 3.2 Every verdict / level carries text and an icon — **FAIL**

**App surfaces — PASS.**

| Surface | Text + icon | Line |
|---|---|---|
| `AnswerCard` giant verdict | word + `checkmark.circle.fill` / `xmark.circle.fill` / `exclamationmark.triangle.fill` | `AnswerCard.swift:31-40`, `VerdictState.swift:23-39` |
| `UnavailableCard` | « Données indisponibles » + warning triangle | `HomeView.swift:166-175` |
| `SwimmingAdvisoryCard` level | `Label(advisory.level.label, systemImage:)` | `SwimmingAdvisoryCard.swift:56-59`, `SwimmingRiskLevel.swift:74-81` |
| `VerdictBadge` (map) | `Label(state.word, systemImage: state.symbolName)` | `SmallComponents.swift:48-57` |
| `SwimmingRiskBadge` (map) | `Label(level.label, systemImage: "exclamationmark.triangle.fill")` | `SmallComponents.swift:62-70` |
| `NextWindowCard` | `Label(headline, systemImage:)` | `NextWindowCard.swift:22-24` |
| `AlertsView` denial | `Label("Notifications désactivées", systemImage: "bell.slash")` | `AlertsView.swift:90-92` |
| `SpotsView` unavailable | `Label("Données indisponibles", systemImage:)` | `SpotsView.swift:137-139` |

Selection is never colour-only either: the `SpotSwitcher` chip swaps `circle` for
`checkmark.circle.fill` (`SpotSwitcher.swift:66`) and carries `.isSelected` (`:84`); the activity
chip carries `.isSelected` (`ActivitySegmentedControl.swift:120`).

**Widget — FAIL.** `GoWidget.swift:45-47`:

```swift
Text(entry.answer)
    .font(OceanTypography.rounded(size: badgeSize))
    .foregroundStyle(OceanPalette.oui)
```

No icon, and the colour is green whatever the answer is — a « Non » would be drawn in
`#34C759`. Colour is the only signal *and* it can carry the wrong meaning. See **F2**.

**Live Activity — FAIL.** `GoLiveActivityView.swift:27` (`Oui`/`Non`, no icon),
`:110` (expanded leading, no icon), and `:146` / `:162` where the compact and minimal
presentations show a bare **`O`** or **`N`**:

```swift
Text(context.state.isGo ? "O" : "N")
```

A single letter is neither the word nor an icon, and VoiceOver reads it as a letter. See **F3**.
The swimming branch is handled correctly: the compact and minimal island show the alert glyph
only, which `DESIGN_REFERENCE.md` §2.1 explicitly requires — but that glyph is then an
*unlabelled meaningful image*, not a decorative one (see §6, and **F3**).

### 3.3 Decorative SF Symbols hidden — **PASS**, four low-risk omissions

Hidden, with the cited line:

| Site | Line |
|---|---|
| `AnswerCard` verdict glyph (meaningful, hidden because the label carries the word) | `AnswerCard.swift:34` |
| `UnavailableCard` triangle | `HomeView.swift:170` |
| `SwimmingAdvisoryCard` warning + notes triangles | `SwimmingAdvisoryCard.swift:25`, `:45` |
| Activity chips: swimming triangle, unavailable circle | `ActivitySegmentedControl.swift:103`, `:107` |
| `ConditionTile` icon | `ConditionsGrid.swift:64` |
| `TipCard` sparkles | `TipCard.swift:17` |
| `SpotSwitcher` chip glyph | `SpotSwitcher.swift:68` |
| `GoWidget` swimming triangle | `GoWidget.swift:76` |
| `GoLiveActivityView` swimming triangle (lock screen) | `GoLiveActivityView.swift:58` |

Not hidden: `ActivitySegmentedControl.swift:72` (chevron in the `Menu` label),
`SpotSwitcher.swift:102` and `:106` (pin and chevron in the `Menu` label),
`SmallComponents.swift:30` (pin in `SpotButton`). All four sit inside a control that carries an
explicit `.accessibilityLabel` (`ActivitySegmentedControl.swift:81`, `SpotSwitcher.swift:114`,
`SmallComponents.swift:42`), and an explicit label replaces the children, so VoiceOver does not
announce them. **O1** proposes the one-line consistency fix; it is not a gate failure.

The Dynamic Island glyphs (`GoLiveActivityView.swift:105`, `:142`, `:158`) are **not**
decorative and must not be hidden — they are the whole message in the compact presentation.
They need a label, which they do not have (**F3**).

### 3.4 Tide chart exposes its next event — **NOT VERIFIABLE**

There is no chart in the tree. `grep -r "Charts\|Chart"` over `Estran` and `EstranWidgets`
returns nothing, there is no `TideChart.swift`, and no spot-detail screen exists
(`Estran/Features/` holds `Home`, `Spots`, `Alerts`, `Settings` only). `DESIGN_REFERENCE.md`
§6 and `worksplit.md` §6 both list `TideChart` and the spot detail as M3 deliverables; they are
unimplemented, so the accessibility requirement has nothing to attach to. See **O5**. This
audit cannot mark the item PASS, and it must not be closed by an absence.

### 3.5 `SpotSwitcher` announces the selected spot and what activating a chip does — **PASS**

`Estran/Features/Spots/SpotSwitcher.swift`:

- **Selected spot announced on appearance:** `:30-35` posts
  `AccessibilityNotification.Announcement("Spot actuel : \(selection.name)")` once, guarded by
  `@State announced` so a camera move does not repeat it — exactly §6.1's rule.
- **Each chip is one element with the spot name as its label:** `:82`.
- **What activating it does:** `:83`
  `.accessibilityHint("Affiche les conditions à \(spot.name)")`.
- **Selection trait:** `:84` `.isSelected` on the active chip only.
- **Tap target:** `:77` `minHeight: OceanGlass.minimumTapHeight` (= 44, `GlassStyles.swift:18`).
- **Menu path (≥ `.accessibility3`):** `:114-115` label « Choisir un spot » and value =
  `selection.name`, so the current spot is still announced and the label states the action.

Whether the announcement is actually heard, and whether `.isSelected` is voiced as « sélectionné »,
is device work (§6).

### 3.6 Activity picker announces selection and unavailable state — **FAIL** (menu path)

`Estran/Features/Home/Components/ActivitySegmentedControl.swift`:

**Chips (below `.accessibility1`) — PASS.** `:118-120` gives every chip the activity's full name
as label, the `accessibilityValue` from `:123-132`, and `.isSelected` on the active one. The
value covers both required facts:

```swift
if activity == .swimming { parts.append("Avertissement baignade, niveau de risque") }
if isUnavailable { parts.append("Données indisponibles") }
```

**Menu (≥ `.accessibility1`) — FAIL.** `:81-82`:

```swift
.accessibilityLabel("Activité")
.accessibilityValue(selection.displayName)
```

The selection is announced; the unavailable state is not. In the menu items (`:52-65`) it is
carried by an `exclamationmark.circle` glyph only, which VoiceOver does not translate into
words. At AX1 and above, a user therefore hears « Activité, Baignade » with no hint that the
data cannot answer. See **F4**.

### 3.7 No `.lineLimit(1)` on a meaningful string — **PASS**

Exactly one `.lineLimit` of 1 exists in the whole scope, at the documented exception:

`EstranWidgets/LiveActivity/GoLiveActivityView.swift:151-155`

```swift
} compactTrailing: {
    Text(context.attributes.spotName)
        .font(OceanTypography.tabLabel)
        .foregroundStyle(OceanPalette.white)
        .lineLimit(1)
}
```

This is the compact Dynamic Island spot name, the single exception written into
`DESIGN_REFERENCE.md` §2.1 (`:96`) and `worksplit.md:144`. No verdict, reason, level, window or
spot name is truncated anywhere else in the app, the widget or the Live Activity.

One adjacent risk, not a violation of this rule: `GoWidget.swift:52` caps `entry.detail` at two
lines — see **O2**.

### 3.8 No `.dynamicTypeSize(...)` clamp — **PASS**

`.dynamicTypeSize` appears three times and always as an **environment read**, never as the
modifier that clamps the range:

- `ActivitySegmentedControl.swift:20` — `@Environment(\.dynamicTypeSize)`
- `ConditionsGrid.swift:12` — same
- `SpotSwitcher.swift:18` — same

No `.dynamicTypeSize(_:)` call exists in `Estran` or `EstranWidgets`. `DESIGN_REFERENCE.md` §2.1
records no justification, and none is needed. Reflow is decided from the environment, as §2.1
requires (`:88`): the segmented control becomes a `Menu` at `.accessibility1`
(`ActivitySegmentedControl.swift:23`), the spot switcher stacks then becomes a `Menu` at
`.accessibility3` (`SpotSwitcher.swift:24`, `:39-41`), and the condition grid drops to one column
at accessibility sizes (`ConditionsGrid.swift:14-22`). All three match the reflow ladder in
`DESIGN_REFERENCE.md` §2.1 (`:77-82`).

### 3.9 No fixed height on a text container; `fixedSize` preserved — **PASS**

**No fixed height anywhere.** `.frame(height:)` does not appear in the scope. Heights are
minimums only: `minHeight: OceanGlass.minimumTapHeight` (`ActivitySegmentedControl.swift:78`,
`:113`; `SpotSwitcher.swift:77`, `:111`; `SmallComponents.swift:39`), which grows with the text
above it and never caps it.

**`fixedSize` is preserved on meaningful text** — 49 call sites, all
`.fixedSize(horizontal: false, vertical: true)`: the giant verdict and both reason lines
(`AnswerCard.swift:39`, `:45`, `:51`), the swimming warning, conditions, notes and level
(`SwimmingAdvisoryCard.swift:30`, `:37`, `:49`, `:59`), the window card (`NextWindowCard.swift:30`,
`:35`, `:40`, `:47`), the tiles (`ConditionsGrid.swift:68`, `:72`), the chips and menu labels
(`ActivitySegmentedControl.swift:70`, `:98`; `SpotSwitcher.swift:72`, `:104`), the map card
(`SpotsView.swift:63`, `:74`, `:79`, `:103`, `:108`, `:114`, `:120`, `:132`, `:143`), the alerts
copy (`AlertsView.swift:63`, `:76`, `:96`, `:113`, `:118`), the attribution
(`HomeView.swift:120`) and the widget / Live Activity swimming blocks (`GoWidget.swift:80`, `:87`,
`:94`, `:104`; `GoLiveActivityView.swift:65`, `:71`, `:78`, `:88`).

**Scaled non-text metrics.** The two display sizes are `@ScaledMetric(relativeTo: .largeTitle)`
and never used raw: `AnswerCard.swift:16-17`, `GoWidget.swift:20-21`,
`GoLiveActivityView.swift:9-10`, with the base constants documented at
`OceanTypography.swift:30-34`. Every text style is a semantic `Font.TextStyle`
(`OceanTypography.swift:12-28`); the only literal `Font.system(size:)` on copy is
`OceanTypography.rounded(size:)` (`:37-39`), fed the already-scaled `wordSize` — permitted by
§2.1 for the display verdict.

Two meaningful strings in the widget extension are not `fixedSize`-protected:
`GoWidget.swift:39-41` (`entry.title`, the spot name) and `GoLiveActivityView.swift:117-119`
(expanded trailing spot name). Neither is capped either, so nothing truncates by construction;
they are listed in **O2** as AX5 risks rather than failures.

### 3.10 Every tappable control is ≥ 44 × 44 pt in code — **FAIL** (one control)

`OceanGlass.minimumTapHeight = 44` (`Estran/Theme/GlassStyles.swift:17-18`) is applied to:

| Control | Line | Result |
|---|---|---|
| Activity chip | `ActivitySegmentedControl.swift:113` | 44 pt + 8 pt vertical padding |
| Activity menu label | `ActivitySegmentedControl.swift:78` | 44 pt |
| Spot chip | `SpotSwitcher.swift:77` | 44 pt |
| Spot menu label | `SpotSwitcher.swift:111` | 44 pt |
| `SpotButton` (Home toolbar) | `SmallComponents.swift:39` | 44 pt |

**Not applied:** the recovery button in the notification-denied card,
`Estran/Features/Alerts/AlertsView.swift:97-104`:

```swift
Button("Ouvrir les réglages") { … }
    .font(OceanTypography.button)
    .foregroundStyle(OceanPalette.turquoise)
```

No padding, no `frame(minHeight:)`, no `contentShape` — its hit area is the text box, roughly
13 pt tall at the default size, and it sits in the one place a user goes when notifications are
off. See **F5**.

**Not decidable from code (system-rendered):** the `Toggle` in `AlertsView.swift:68-86`, the
`List` row button in `SettingsView.swift:23-26` (a `List` row is ≥ 44 pt by construction, but
the code asserts nothing), the four tab items (`RootView.swift:13-27`), and the map `Marker`
(`SpotsView.swift:19-23`). These belong to the device pass (§6).

`AccessibilityTourUITests` measures every `button` / `switch` / `link` frame against 44 pt
(`EstranUITests/AccessibilityTourUITests.swift:96-142`), but it never opens the denied card — the
tour does not toggle the switch — so it would not catch **F5** as written.

### 3.11 Tutoiement, and no « Oui » for swimming on any surface — **PASS** in the app

**Tutoiement.** No `vous` / `votre` / `vos` form exists anywhere in `Estran`, `EstranWidgets` or
`Packages/EstranCore/Sources`. The swimming copy is consistently second-person singular:
« Reste dans une zone surveillée, jamais seul, et garde les enfants à portée de main »,
« Baigne entre les drapeaux », « Si un courant t'emporte, ne lutte pas »
(`SwimmingRiskLevel.swift:85-108`). « Ouvrir les réglages » is an infinitive button label, not a
vouvoiement.

**No « Oui » for swimming.** Every path is gated in code:

| Surface | Gate | Line |
|---|---|---|
| Home card | `if app.activity == .swimming` → `SwimmingAdvisoryCard`, else `AnswerCard` | `HomeView.swift:85-95` |
| Home window card | not rendered for swimming at all | `HomeView.swift:30` |
| Home tip | suppressed for swimming | `HomeView.swift:42` |
| Map verdict | `if app.activity == .swimming` → risk warning + `SwimmingRiskBadge` | `SpotsView.swift:93-121` |
| Map unavailable | swimming branch shows `unknown.warning` + risk badge | `SpotsView.swift:127-134` |
| Widget | `if entry.isSwimming { swimmingBody }` | `GoWidget.swift:25-29` |
| Live Activity (lock screen) | same flag | `GoLiveActivityView.swift:14-18` |
| Compact / minimal island | same flag → alert glyph, never « O » | `GoLiveActivityView.swift:141-150`, `:157-166` |

The string « Oui » survives only where it is legitimate: `VerdictState.swift:25`,
`AnswerCard.swift:89` (never reached for swimming), and the Live Activity non-swimming branches
(`GoLiveActivityView.swift:27`, `:110`). No green is used on a swimming surface:
`OceanPalette.swimmingRisk` returns `turquoise` / `sand` / `non` / `unavailable`, never `oui`
(`OceanPalette.swift:27-35`).

**Widget and Live Activity: NOT VERIFIABLE.** Both gate on a boolean flag (`isSwimming`) that no
production code sets yet — `GoTimelineProvider` returns a single placeholder entry
(`EstranWidgets/TimelineProviders/GoTimelineProvider.swift:5-15`) and nothing in `Estran/` starts
a Live Activity. The *branches* are correct; that the production snapshot fills them correctly is
M5 work (`worksplit.md` §6 M5, review v10 point 2). See **O6**. Note that a swimming entry that
reached the non-swimming branch would also be drawn in green, because of **F2**.

### 3.12 Warning + « L'app estime les courants de marée… » inside the VoiceOver element — **FAIL** (expanded Dynamic Island)

The sentence is `SwimmingRiskLevel.disclaimer`
(`Packages/EstranCore/Sources/EstranCore/Models/SwimmingRiskLevel.swift:105-108`) and is appended
to the permanent coast warning at `:98`, so `warning(for:)` always contains both.

| Surface | Warning | Disclaimer | One element? |
|---|---|---|---|
| Home swimming card | `SwimmingAdvisoryCard.swift:27-30` (via `advisory.warning`) | inside the same string | **Yes** — `:64-65` `children: .ignore` + `advisory.accessibilitySentence` (`SwimmingAdvisory.swift:47-57`) |
| Map spot card | `SpotsView.swift:100-103` (short form) | `:117-120` | No — separate elements, both reachable |
| Widget | `GoWidget.swift:77-81` (short form) | `:101-104` | No — separate elements, both reachable |
| Live Activity (lock screen) | `GoLiveActivityView.swift:62-65` | `:85-88` | No — separate elements, both reachable |
| **Expanded Dynamic Island** | `GoLiveActivityView.swift:125-128` (short form) | **absent** | No |

The app card satisfies `worksplit.md:136` exactly: one element, warning first, then the
conditions line, then the blockers, then the secondary level, with the disclaimer inside the
warning string. The expanded Dynamic Island, however, renders only the short warning and
« Courants : … » (`:121-139`) — the « L'app estime les courants de marée. Elle ne voit ni les
baïnes, ni les maîtres-nageurs. » sentence is missing from that surface entirely, so it is not in
any element there. See **F6**.

## 4. Failures, with minimal corrections

No production code was edited. Each correction is the smallest change that closes the finding.

### F1 — `AnswerCard` speaks a paraphrase instead of the displayed reason (item 1)

- **Where:** `Estran/Features/Home/Components/AnswerCard.swift:88-93`, against the visible line at
  `:42-45`.
- **Now:** `case .go: var sentence = "Oui, \(activity.displayName), conditions réunies."`
- **Change:** read the same string the card draws, exactly as `.noGo` does at `:95`:

  ```swift
  case .go:
      var sentence = "Oui, \(activity.displayName). \(decision.reason)"
  ```

  Keep the `detail` append at `:90-92` unchanged.
- **Why minimal:** one expression; the tide detail line and the single-element structure are
  untouched; it stops the spoken and visible reason from diverging when M4 replaces the reason
  with generated text.

### F2 — Widget verdict has no icon and is always green (item 2)

- **Where:** `EstranWidgets/GoWidget.swift:45-47`.
- **Now:** `Text(entry.answer)` with `.foregroundStyle(OceanPalette.oui)` unconditionally.
- **Change:** (a) add `var isGo: Bool = true` to `GoEntry` (`:5-13`), next to `isSwimming`, and
  have the M5 snapshot fill it; (b) render the verdict as a `Label` so the icon and the colour
  come from the same source:

  ```swift
  Label(entry.answer, systemImage: entry.isGo ? "checkmark.circle.fill" : "xmark.circle.fill")
      .font(OceanTypography.rounded(size: badgeSize))
      .foregroundStyle(entry.isGo ? OceanPalette.oui : OceanPalette.non)
  ```

- **Why minimal:** one model property with a default (the placeholder keeps compiling) and one
  view expression; no layout change, no new component.
- **Not to be fixed by** removing the `@ScaledMetric` or the `.lineLimit(2)`.

### F3 — Live Activity verdict has no icon; compact and minimal say « O » / « N » (item 2)

- **Where:** `EstranWidgets/LiveActivity/GoLiveActivityView.swift:27`, `:110`, `:146`, `:162`.
- **Change, part 1 (lock screen and expanded leading):** use `Label` instead of `Text` at `:27`
  and `:110`, with `checkmark.circle.fill` / `xmark.circle.fill` and the existing
  `isGo ? oui : non` colour.
- **Change, part 2 (compact and minimal):** there is no room for the word, so keep the letter
  and make VoiceOver read the word, not the letter:

  ```swift
  Text(context.state.isGo ? "O" : "N")
      .accessibilityLabel(context.state.isGo ? "Oui" : "Non")
  ```

  at both `:146-150` and `:162-166`.
- **Change, part 3 (swimming glyph):** the glyph at `:142` / `:158` is the whole message, so give
  it a label instead of hiding it:

  ```swift
  Image(systemName: "exclamationmark.triangle.fill")
      .accessibilityLabel("Baignade : risque de courants")
  ```

  (the expanded region's glyph at `:105` already sits next to the warning text in the bottom
  region, so a label there is optional; `.accessibilityHidden(true)` would be wrong, because the
  glyph is the only level signal in the leading region).
- **Note:** « O » / « N » is a visual abbreviation the design reference does not document
  (`DESIGN_REFERENCE.md` §3.4 shows full words). If it is kept, §2.1 should record it as a
  width-constrained exception, like the compact spot name at `:96`. That is a doc decision for
  the Lead, not something this audit edits.

### F4 — Activity menu does not announce the unavailable state (item 6)

- **Where:** `Estran/Features/Home/Components/ActivitySegmentedControl.swift:81-82`.
- **Now:** `.accessibilityValue(selection.displayName)`.
- **Change:** append the same fact the chips carry, reusing the existing helper, so the two
  branches cannot drift:

  ```swift
  private var menuValue: String {
      let detail = accessibilityValue(
          for: selection, isUnavailable: unavailable.contains(selection))
      return detail.isEmpty ? selection.displayName : "\(selection.displayName), \(detail)"
  }
  ```

  then `.accessibilityValue(menuValue)` at `:82`.
- **Why minimal:** no new strings — « Données indisponibles » and « Avertissement baignade,
  niveau de risque » already exist at `:123-132`.

### F5 — « Ouvrir les réglages » is below 44 pt (item 10)

- **Where:** `Estran/Features/Alerts/AlertsView.swift:97-104`.
- **Change:** add the standard minimum below `.foregroundStyle`:

  ```swift
  .frame(minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
  .contentShape(Rectangle())
  ```

  `OceanGlass` is already in scope (`:81` uses `OceanGlass.cardCornerRadius`).
- **Why minimal:** two modifiers, no layout redesign, consistent with every other control in the
  app.

### F6 — Expanded Dynamic Island omits « L'app estime les courants de marée… » (item 12)

- **Where:** `EstranWidgets/LiveActivity/GoLiveActivityView.swift:121-139` — the swimming branch
  renders `widgetWarning` and « Courants : … » only.
- **Change:** add the shared constant after the level line, inside the same `VStack`:

  ```swift
  Text(SwimmingRiskLevel.disclaimer)
      .font(OceanTypography.smallLabel)
      .foregroundStyle(OceanPalette.white.opacity(0.7))
      .fixedSize(horizontal: false, vertical: true)
  ```

  (identical to the lock-screen block at `:85-88`, so the two surfaces cannot drift).
- **Why minimal:** one `Text` from an existing constant. If the expanded island cannot take the
  extra line at AX5, the correct answer is a `ViewThatFits` that keeps the disclaimer and drops
  the conditions line — never the reverse: `DESIGN_REFERENCE.md` §2.1 (`:97`) forbids removing
  the warning from a surface to compensate.

## 5. Observations — not gate failures

- **O1 — four decorative glyphs are not hidden.** `ActivitySegmentedControl.swift:72`,
  `SpotSwitcher.swift:102`, `:106`, `SmallComponents.swift:30`. Each parent has an explicit
  `.accessibilityLabel`, so VoiceOver does not announce them; adding `.accessibilityHidden(true)`
  would match the convention of every other glyph and cost nothing.
- **O2 — `.lineLimit(2)` on a meaningful string.** `GoWidget.swift:52` caps `entry.detail` at two
  lines. Not the forbidden `.lineLimit(1)`, and §2.1 is silent on `(2)`, but the detail line is
  « Jusqu'à 15 h 40 »-class content: at AX5 in `.systemSmall` two lines will not hold it. Either
  drop the cap and let the widget's stacked layout absorb it, or record it as an exception in
  §2.1. Related, `GoWidget.swift:39-41` and `GoLiveActivityView.swift:117-119` (spot name) have
  neither a cap nor `fixedSize`, so they wrap but may be compressed.
- **O3 — the widget, the Live Activity and the map card are not single elements.** Each text is
  its own VoiceOver stop. Nothing is missing from the output, but the reading order is
  container-driven rather than authored, and a user must swipe five to seven times through the
  swimming block. A single `accessibilityElement(children: .combine)` on `GoWidgetView`'s
  swimming body (or an `accessibilityLabel` built like `SwimmingAdvisory.accessibilitySentence`)
  would give the widget the same parity the app card already has.
- **O4 — `OceanGlass.minimumTapHeight` is a constant 44, not `@ScaledMetric`.** Correct as a
  floor (§2.1 requires chips to "grow with Dynamic Type, they do not shrink below it", and the
  text above the floor makes them grow), but worth stating so nobody later reads it as a cap.
- **O5 — no `TideChart`, no spot detail screen.** The M3 scope of `worksplit.md` §6 and
  `DESIGN_REFERENCE.md` §3.2 is not implemented in this tree. Item 4 of this audit cannot be
  evaluated, and the map `Marker` (`SpotsView.swift:19-23`) carries only the spot name, not the
  verdict that §3.5 (`:176`) describes.
- **O6 — the widget / Live Activity data path is not wired.** `GoTimelineProvider` returns
  `.placeholder` for snapshot and timeline (`GoTimelineProvider.swift:9-15`), whose `answer` is
  « — » (`:19-23`) — honest, and the reason item 11 cannot be closed for those surfaces. This is
  the M5 checklist item, not a defect of the views.
- **O7 — no `accessibilityHeading` and no custom rotor anywhere.** `grep` finds no
  `.accessibilityHeading`, `.accessibilityRotor` or `.accessibilitySortPriority` in the scope.
  VoiceOver's rotor will therefore offer only the defaults. Not required by the M3 checklist, but
  the swimming card and the answer card are the two obvious heading candidates, and a « Créneaux »
  rotor would matter on the map.

## 6. Not verifiable from source — required device checklist

None of the following can be settled by reading Swift. Each needs a real VoiceOver session on
hardware, with the listed setup.

1. **Spoken order inside every combined element.** `accessibilityElement(children: .combine)`
   (`HomeView.swift:150`, `:185`; `ConditionsGrid.swift:77`; `TipCard.swift:32`;
   `NextWindowCard.swift:53`) and `children: .ignore` with a hand-built sentence
   (`AnswerCard.swift:57-58`; `SwimmingAdvisoryCard.swift:64-65`) both depend on runtime
   composition. Check that the order matches the visual order and that no punctuation produces
   « … °C. . ».
2. **The `AccessibilityNotification.Announcement` at `SpotSwitcher.swift:33-34`.** Does it fire
   once, is it audible over the tab-change announcement, does it interrupt, and does it repeat
   when the tab is revisited (the `@State announced` guard resets with the view)?
3. **The `.isSelected` trait** on the spot chips (`SpotSwitcher.swift:84`) and the activity chips
   (`ActivitySegmentedControl.swift:120`) — is it voiced, and is it distinct from the check
   glyph?
4. **The `Menu` presentations** at `.accessibility1` (activity) and `.accessibility3` (spot) —
   system-rendered items, their labels, and whether the value set at
   `ActivitySegmentedControl.swift:82` and `SpotSwitcher.swift:115` is announced on focus.
5. **Actual 44 × 44 pt frames.** Run `EstranUITests/AccessibilityTourUITests` and read the
   `tap-targets-*` attachments (`AccessibilityTourUITests.swift:96-142`), then **open the
   notification-denied card by hand** — the tour does not reach `AlertsView.swift:97` (F5).
6. **AX5 clipping on every screen.** The app screens are in a `ScrollView` (`HomeView.swift:14`,
   `AlertsView.swift:22`) so growth is structural, but verify: the toolbar `SpotButton` and
   `SampleDataBadge` at AX5, the map's floating stack (`SpotsView.swift:31-40`, which has no
   scroll), and the `List` in `SettingsView` at AX5.
7. **AX5 in the widget and Live Activity.** `GoWidgetView.swimmingBody` stacks seven text blocks
   plus a `Spacer` in `.systemSmall` (`GoWidget.swift:58-108`) with no reflow, `ViewThatFits` or
   scroll; `GoLiveActivityView.swimmingBody` stacks six (`:45-94`). §2.1 (`:90`) makes clipping
   at AX5 a gate failure. This is the highest-risk item in the whole audit and it cannot be
   judged statically.
8. **Compact Dynamic Island width.** Confirm the spot name truncates gracefully at `:155` and
   that the truncation is the only one — the documented exception is only defensible if the full
   name is present in the expanded presentation (`:117`).
9. **Whether the swimming glyph alone is intelligible** in compact and minimal (`:142`, `:158`)
   once it has a label (F3). §2.1 (`:97`) accepts the glyph-only compact island; the test is
   whether a VoiceOver user understands it without the word « baïnes ».
10. **MapKit and TabView accessibility.** The `Marker` label and trait
    (`SpotsView.swift:19-23`), the four tab items (`RootView.swift:13-27`), and whether
    `interactionModes: []` (`SpotsView.swift:18`) leaves the map as a non-focusable element.
11. **Contrast of the low-opacity copy** — `white.opacity(0.6)` attribution
    (`HomeView.swift:119`), `0.7` overlines (`AnswerCard.swift:28`,
    `SwimmingAdvisoryCard.swift:19`), `0.75` labels (`ConditionsGrid.swift:71`). `worksplit.md`
    §6 requires ≥ 4.5:1 on body text; the sand `unavailable` colour on glass
    (`OceanPalette.swift:23`) is the one to measure first.
12. **Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, Differentiate Without
    Colour.** Only Reduce Motion has code (`SpotsView.swift:48-54`,
    `SpotSwitcher.swift:51-53`); the others are M6 re-verification items
    (`worksplit.md` §6 M6) and none of them can be read from the source.
13. **Siri and Shortcuts surfaces.** No App Intents code exists yet (M4), so the invariant « no
    `Oui` for swimming » is unenforced and unverifiable there.
14. **Rotor.** No `.accessibilityHeading` and no `.accessibilityRotor` exists anywhere (O7), so
    the rotor will offer only the system defaults. Confirm what it actually offers on each
    screen, and whether moving through the long Home scroll (answer card → window card → four
    tiles → tip → attribution) stays workable without headings.

## 7. What would close the M3 accessibility gate

1. Fix F1–F6 (six small, local edits; none of them a layout redesign, none of them a removed
   accessibility modifier).
2. Run the device checklist in §6 on hardware, at AX5 and at the default size, on all four tabs,
   all five activities, both spots, the swimming card in all four states
   (`low` / `moderate` / `strong` / `unknown`), the widget in S and M, the lock-screen Live
   Activity and the three Dynamic Island presentations.
3. Record the result in `worksplit.md` §6 as evidence, not as a claim: this audit deliberately
   says PASS only where the source says so.

## 8. Reproduction

Every static claim above is a `grep` away, from the repository root:

```sh
# Dynamic Type clamps, line limits, fixed heights, scaled text
grep -rn -E "dynamicTypeSize|lineLimit|frame\(height|fixedSize|minimumScaleFactor|allowsTightening" \
  Estran EstranWidgets --include="*.swift"

# Every accessibility modifier in the shipped UI
grep -rn "accessibility" Estran EstranWidgets --include="*.swift"

# « Oui » occurrences (expected: VerdictState, AnswerCard, the Live Activity
# non-swimming branches, and the OceanPalette / OceanTypography tokens)
grep -rn -E "Oui|\boui\b" Estran EstranWidgets --include="*.swift"

# Vouvoiement (expected: no output)
grep -rn -E "\b(vous|Vous|votre|Votre|vos|Vos)\b" Estran EstranWidgets \
  Packages/EstranCore/Sources --include="*.swift"

# Charts (expected: no output — no TideChart exists)
grep -rn -E "Chart|Charts|TideChart" Estran EstranWidgets --include="*.swift"
```

`git status` at the time of the audit: branch `dev`, HEAD `4ae8731`, 17 modified files and two
untracked paths (`Estran/Resources/Assets.xcassets/AppIcon.appiconset/`,
`EstranUITests/AccessibilityTourUITests.swift`) from the Lead's in-flight work, plus this
document.

## Lead review and remediation (2026-10-28, after this audit)

| Finding | Status | Where |
|---|---|---|
| F1 — answer card spoke a paraphrase | **Fixed** — `.go` now speaks `decision.reason`, the line the card draws | `AnswerCard.swift` |
| F2 — widget verdict always green | **Fixed for the defect**: `GoEntry.isGo` drives both colour and word. The icon was **not** added: the 48 pt widget verdict already carries the word, and `DESIGN_REFERENCE.md` §3.4 draws it without a glyph. | `GoWidget.swift` |
| F3 — Live Activity verdict without icon, « O »/« N » | **Fixed** — `Label` on the lock screen and the expanded leading region; compact and minimal letters speak « Oui »/« Non »; the swimming glyph is labelled instead of hidden | `GoLiveActivityView.swift` |
| F4 — activity menu did not announce the unavailable state | **Fixed** — the menu value reuses the chip helper, so « Données indisponibles » and the swimming warning reach both branches | `ActivitySegmentedControl.swift` |
| F5 — « Ouvrir les réglages » below 44 pt | **Fixed** — `minHeight: 44` + `contentShape` | `AlertsView.swift` |
| F6 — expanded island dropped the disclaimer | **Fixed** — the lock-screen disclaimer is now inside the expanded bottom region | `GoLiveActivityView.swift` |

Two related corrections outside the finding list:

- the tinted verdict colour on glass is now `nonOnGlass` / `turquoiseOnGlass`
  for small text (see `contrast-audit.md`, Lead review) — a colour change only,
  no label change;
- `ConditionsGrid` captions are short words (« baisse », « km/h O ») while the
  accessibility label keeps the full sentence, so VoiceOver still reads
  « Marée : 4,5 m, marée descendante ».

The device checklist in §6 is unchanged: none of the above proves spoken order,
rotor behaviour or real VoiceOver output.
