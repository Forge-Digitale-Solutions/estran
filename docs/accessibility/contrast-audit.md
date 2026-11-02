# Contrast audit — WCAG 2.1 AA

|                 |                                                                                                   |
| --------------- | ------------------------------------------------------------------------------------------------- |
| **Date**        | 2026-10-28                                                                                        |
| **Scope**       | `Estran/Theme/OceanPalette.swift`, `OceanTypography.swift`, `GlassStyles.swift`, `Estran/Features/**`, `EstranWidgets/**` |
| **Branch**      | `dev` (uncommitted Lead changes)                                                                   |
| **Gate**        | `worksplit.md` §6 M3 — contrast ≥ 4.5:1 on body text                                               |
| **Kind**        | static audit — no simulator run, no pixel sampling                                                 |
| **Method**      | WCAG 2.1 relative luminance, sRGB source-over compositing, Python 3 stdlib                         |
| **Pairs**       | 118 rendered pairs: 52 on exact backgrounds, 50 on glass, 16 not verifiable                        |

## 1. Summary

**6 pairs fail** the threshold at the audited glass model, **22 more pass only inside
the model** (they fail before the 25 % pessimistic bound), **74 pass with headroom**, and **16 cannot be
verified statically** because their backdrop is MapKit raster content or system chrome.

Every failure is a coloured accent, never a white or sand label:

1. **`non` `#FF6B5B` cannot be 13 pt text anywhere on the app's gradient.** Its best case is
   4.04:1 (widget, top of the gradient); on a glass card it is 2.62:1. This is the only colour
   that fails on an *exact* background, so it is not an artefact of the glass model.
2. **`non` as the giant « Non » verdict** (76 pt bold, 3:1) passes only while the glass adds
   less than **10.4 %** white: 4.04:1 on the bare gradient, 3.04:1 at 10 % glass, 2.62:1 at the
   audited 15 % model.
3. **`turquoise` `#30D5C8` as 13 pt text** is 4.01:1 on glass and breaks 4.5:1 above **11.1 %**
   glass fill — the swimming level « faibles » and the « Ouvrir les réglages » button.
4. **White at 70 % opacity** is the weakest white label: 4.55:1 on glass, exactly on the line,
   and it breaks at **15.4 %** glass fill. It carries three eyebrows, the swimming disclaimer and
   the widget's « Baignade » label.

Everything else passes with headroom, including every Live Activity pair (6.63–18.55:1),
the Dynamic Island (7.51–21:1), the white selected pill (12.24:1) and the sand badge (12.64:1).

## 2. Method

### 2.1 Relative luminance and contrast ratio

Per WCAG 2.1 §1.4.3 and the relative-luminance definition:

```
c_srgb = channel / 255
c_lin  = c_srgb / 12.92                      if c_srgb <= 0.03928
c_lin  = ((c_srgb + 0.055) / 1.055) ^ 2.4    otherwise
L      = 0.2126 R_lin + 0.7152 G_lin + 0.0722 B_lin
ratio  = (L_light + 0.05) / (L_dark + 0.05)
```

No rounding is applied to the ratio; the tables print two decimals and compare the unrounded
value against the threshold, so a printed `4.55` is a real pass and a printed `4.50` is a real pass.

### 2.2 Compositing

Translucent layers are composited with standard **source-over in sRGB space** (the non-linear
values, which is what SwiftUI `.opacity()` and a `.foregroundStyle(Color.opacity(a))` do):

```
composite = alpha * foreground + (1 - alpha) * background      (per channel, 0…255)
```

The composite is then converted to luminance. A translucent *foreground* is composited over its
already-composited background; a translucent *background* is composited bottom-up before the
foreground is applied. The `Composite` column is the effective rendered colour of the foreground
after that compositing, so it can be pasted into any contrast checker to reproduce the ratio.

### 2.3 Backgrounds

| Surface | Value | Luminance |
| --- | --- | --- |
| `backgroundGradient` top | `#0A3D62` | 0.0428 |
| `backgroundGradient` bottom | `#031426` | 0.0066 |
| Glass card, audited model | `#2F5A7A` | 0.0932 |
| Selected white pill, audited model | `#DFE1E3` | 0.7510 |
| `sand` badge (opaque) | `#F2E3C2` | 0.7771 |
| Live Activity `activityBackgroundTint` | `#031426` | 0.0066 |
| Dynamic Island | `#000000` | 0.0000 |

**Both gradient ends are tested and the worse one is reported.** The gradient is attached to the
`ScrollView` with `.ignoresSafeArea()`, so it is fixed to the viewport while the content scrolls
over it: any card can sit at the top of the screen, on the brighter end. The `Background` column
names the end that produced the ratio, so a reader can tell which way the number moves.

For the widget the content does not scroll, so the reported number is a *floor*: a line that sits
lower in the widget is on a darker part of the gradient and scores higher.

### 2.4 The glass surface

`.glassEffect(.regular, in:)` (`GlassStyles.swift:25-33`) draws a **system-owned** translucent
fill. Its opacity is not public API and is not specified in the repository —
`DESIGN_REFERENCE.md` §1 records only that Figma approximates it with a white fill plus a
`#BFD9FF` tint, and explicitly says not to hard-code the alpha. A glass surface over the gradient
is therefore **not derivable exactly**; it is bracketed and the bracket is reported.

The audited model is **15 % white over the gradient end**, i.e. `#2F5A7A` over the top end:

```
glass = 0.15 * #FFFFFF + 0.85 * #0A3D62 = #2F5A7A
```

That is the pessimistic end of the plausible range for `.regular` glass over a dark backdrop
(5–15 %), so a PASS at this model is a PASS for a darker rendering, and a FAIL is a genuine
risk rather than a certainty. §8 tabulates every pair from 0 % (perfectly transparent glass) to
30 %, and the `Margin` column of table B gives, for each pair, **the largest white fill that still
meets its threshold**. Read that column before acting on a verdict: `Margin 32 %` is a robust pass,
`Margin 11 %` is not.

The selected chip uses `.regular.tint(OceanPalette.white)` (`ActivitySegmentedControl.swift:89`,
`SpotSwitcher.swift:59`). It is modelled as 85 % white over the glass; the minimum effective white
tint that keeps `ink` `#06223F` at 4.5:1 is **40.7 %**, so the pair is safe as long as the pill
really renders near-white. At 85 % it is 12.24:1.

### 2.5 Thresholds

| Class | Threshold | Applied to |
| --- | --- | --- |
| Normal text | 4.5:1 | every style below 18 pt that is not bold |
| Large text | 3:1 | ≥ 18 pt, or ≥ 14 pt **bold** (WCAG 1.4.3) |
| Icons / non-text | 3:1 | SF Symbols carrying meaning (WCAG 1.4.11) |

Point sizes are the default Dynamic Type sizes documented in `OceanTypography.swift`:
`largeTitle` 34, `metricValue` 22, `body` 17, `subtitle` 15, `button`/`caption` 13,
`smallLabel`/`tabLabel` 11, and the two scaled display sizes 76 and 48 pt. **17 pt semibold is
treated as normal text** (4.5:1): semibold is not bold, so the 14 pt-bold exemption does not
apply. 22 pt semibold and above qualify as large text on size alone. This is the conservative
reading; it does not change any verdict in this report.

### 2.6 Reproducing a row

Pick a row, take the `Foreground` hex and opacity, take the `Background` hex, composite as in
§2.2, and run the result through the formula in §2.1. The `Composite` column should match.

## 3. Table A — exact backgrounds

Gradient, opaque sand badge, widget background, Live Activity tint, Dynamic Island. No modelling:
these numbers are final.

| # | Element | Source | Foreground | Background | Composite | Ratio | Threshold | Verdict |
|---|---|---|---|---|---|---|---|---|
| A1 | Title « Maintenant » | `HomeView.swift:65-66` | #FFFFFF | `#0A3D62` | `#FFFFFF` | **11.31** | 3.0 | PASS |
| A2 | Subtitle « spot · heure » | `HomeView.swift:72-73` | #FFFFFF 80 % | `#0A3D62` | `#CED8E0` | **7.83** | 4.5 | PASS |
| A3 | Footer attribution (REFMAR) | `HomeView.swift:118-119` | #FFFFFF 60 % | `#0A3D62` | `#9DB1C0` | **5.13** | 4.5 | PASS |
| A4 | Title « Alertes » | `AlertsView.swift:58-59` | #FFFFFF | `#0A3D62` | `#FFFFFF` | **11.31** | 3.0 | PASS |
| A5 | Alerts subtitle | `AlertsView.swift:61-62` | #FFFFFF 80 % | `#0A3D62` | `#CED8E0` | **7.83** | 4.5 | PASS |
| A6 | Alerts footer note (2 sentences) | `AlertsView.swift:112-121` | #FFFFFF 60 % | `#0A3D62` | `#9DB1C0` | **5.13** | 4.5 | PASS |
| A7 | Settings — `.secondary` values and paragraphs † | `SettingsView.swift:19-21, :32, :41, :51` | #FFFFFF 60 % | `#0A3D62` | `#9DB1C0` | **5.13** | 4.5 | PASS |
| A8 | Button « Voir la licence » (accent tint) | `SettingsView.swift:23-25` | #30D5C8 | `#0A3D62` | `#30D5C8` | **6.18** | 4.5 | PASS |
| A9 | SampleDataBadge — « Données d'exemple » | `SmallComponents.swift:11-16` | #06223F | `#F2E3C2` | `#06223F` | **12.64** | 4.5 | PASS |
| A10 | GoWidget — spot title | `GoWidget.swift:39-41` | #F2E3C2 | `#0A3D62` | `#F2E3C2` | **8.91** | 4.5 | PASS |
| A11 | GoWidget — « Oui » verdict | `GoWidget.swift:45-47` | #34C759 | `#0A3D62` | `#34C759` | **5.09** | 3.0 | PASS |
| A12 | GoWidget — detail line | `GoWidget.swift:49-51` | #FFFFFF 80 % | `#0A3D62` | `#CED8E0` | **7.83** | 4.5 | PASS |
| A13 | GoWidget — « Baignade » | `GoWidget.swift:68-70` | #FFFFFF 70 % | `#0A3D62` | `#B6C5D0` | **6.38** | 4.5 | PASS |
| A14 | GoWidget — alert icon | `GoWidget.swift:73-75` | #F2E3C2 | `#0A3D62` | `#F2E3C2` | **8.91** | 3.0 | PASS |
| A15 | GoWidget — warning | `GoWidget.swift:77-79` | #FFFFFF | `#0A3D62` | `#FFFFFF` | **11.31** | 4.5 | PASS |
| A16 | GoWidget — conditions line | `GoWidget.swift:83-86` | #FFFFFF 85 % | `#0A3D62` | `#DAE2E7` | **8.63** | 4.5 | PASS |
| A17 | GoWidget — blockers | `GoWidget.swift:90-93` | #F2E3C2 | `#0A3D62` | `#F2E3C2` | **8.91** | 4.5 | PASS |
| A18 | GoWidget — « Courants : faibles » | `GoWidget.swift:97-99` | #30D5C8 | `#0A3D62` | `#30D5C8` | **6.18** | 4.5 | PASS |
| A19 | GoWidget — « Courants : modérés » | `GoWidget.swift:97-99` | #F2E3C2 | `#0A3D62` | `#F2E3C2` | **8.91** | 4.5 | PASS |
| A20 | GoWidget — « Courants : forts » | `GoWidget.swift:97-99` | #FF6B5B | `#0A3D62` | `#FF6B5B` | **4.04** | 4.5 | **FAIL** |
| A21 | GoWidget — « Courants : non estimés » | `GoWidget.swift:97-99` | #F2E3C2 | `#0A3D62` | `#F2E3C2` | **8.91** | 4.5 | PASS |
| A22 | GoWidget — disclaimer | `GoWidget.swift:101-103` | #FFFFFF 70 % | `#0A3D62` | `#B6C5D0` | **6.38** | 4.5 | PASS |
| A23 | ConditionsWidget — title | `ConditionsWidget.swift:15-17` | #F2E3C2 | `#0A3D62` | `#F2E3C2` | **8.91** | 4.5 | PASS |
| A24 | ConditionsWidget — labels | `ConditionsWidget.swift:21-23` | #FFFFFF 80 % | `#0A3D62` | `#CED8E0` | **7.83** | 4.5 | PASS |
| A25 | Live Activity — « Oui » | `GoLiveActivityView.swift:27-29` | #34C759 | `#031426` | `#34C759` | **8.36** | 3.0 | PASS |
| A26 | Live Activity — « Non » | `GoLiveActivityView.swift:27-29` | #FF6B5B | `#031426` | `#FF6B5B` | **6.63** | 3.0 | PASS |
| A27 | Live Activity — spot name | `GoLiveActivityView.swift:32-34` | #FFFFFF | `#031426` | `#FFFFFF` | **18.55** | 4.5 | PASS |
| A28 | Live Activity — activity name | `GoLiveActivityView.swift:35-37` | #F2E3C2 | `#031426` | `#F2E3C2` | **14.61** | 4.5 | PASS |
| A29 | Live Activity — « Baignade » | `GoLiveActivityView.swift:52-54` | #F2E3C2 | `#031426` | `#F2E3C2` | **14.61** | 4.5 | PASS |
| A30 | Live Activity — alert icon | `GoLiveActivityView.swift:56-57` | #F2E3C2 | `#031426` | `#F2E3C2` | **14.61** | 3.0 | PASS |
| A31 | Live Activity — warning | `GoLiveActivityView.swift:62-64` | #FFFFFF | `#031426` | `#FFFFFF` | **18.55** | 4.5 | PASS |
| A32 | Live Activity — conditions line | `GoLiveActivityView.swift:67-70` | #FFFFFF 85 % | `#031426` | `#D9DCDE` | **13.45** | 4.5 | PASS |
| A33 | Live Activity — blockers | `GoLiveActivityView.swift:74-77` | #F2E3C2 | `#031426` | `#F2E3C2` | **14.61** | 4.5 | PASS |
| A34 | Live Activity — « Courants : faibles » | `GoLiveActivityView.swift:81-83` | #30D5C8 | `#031426` | `#30D5C8` | **10.14** | 4.5 | PASS |
| A35 | Live Activity — « Courants : modérés » | `GoLiveActivityView.swift:81-83` | #F2E3C2 | `#031426` | `#F2E3C2` | **14.61** | 4.5 | PASS |
| A36 | Live Activity — « Courants : forts » | `GoLiveActivityView.swift:81-83` | #FF6B5B | `#031426` | `#FF6B5B` | **6.63** | 4.5 | PASS |
| A37 | Live Activity — « Courants : non estimés » | `GoLiveActivityView.swift:81-83` | #F2E3C2 | `#031426` | `#F2E3C2` | **14.61** | 4.5 | PASS |
| A38 | Live Activity — disclaimer | `GoLiveActivityView.swift:85-87` | #FFFFFF 70 % | `#031426` | `#B3B8BE` | **9.34** | 4.5 | PASS |
| A39 | Live Activity — footer spot name | `GoLiveActivityView.swift:90-92` | #FFFFFF 80 % | `#031426` | `#CDD0D4` | **11.97** | 4.5 | PASS |
| A40 | Live Activity — system action colour | `GoLiveActivityView.swift:22` | #30D5C8 | `#031426` | `#30D5C8` | **10.14** | 4.5 | PASS |
| A41 | Dynamic Island — « Oui », expanded | `GoLiveActivityView.swift:110-113` | #34C759 | `#000000` | `#34C759` | **9.46** | 3.0 | PASS |
| A42 | Dynamic Island — « Non », expanded | `GoLiveActivityView.swift:110-113` | #FF6B5B | `#000000` | `#FF6B5B` | **7.51** | 3.0 | PASS |
| A43 | Dynamic Island — risk icon, expanded | `GoLiveActivityView.swift:105-108` | #FF6B5B | `#000000` | `#FF6B5B` | **7.51** | 3.0 | PASS |
| A44 | Dynamic Island — spot name (trailing) | `GoLiveActivityView.swift:117-119` | #FFFFFF | `#000000` | `#FFFFFF` | **21.00** | 4.5 | PASS |
| A45 | Dynamic Island — warning (bottom) | `GoLiveActivityView.swift:125-128` | #FFFFFF | `#000000` | `#FFFFFF` | **21.00** | 4.5 | PASS |
| A46 | Dynamic Island — « Courants : forts » (bottom) | `GoLiveActivityView.swift:129-132` | #FF6B5B | `#000000` | `#FF6B5B` | **7.51** | 4.5 | PASS |
| A47 | Dynamic Island — activity name (bottom) | `GoLiveActivityView.swift:135-137` | #F2E3C2 | `#000000` | `#F2E3C2` | **16.54** | 4.5 | PASS |
| A48 | Dynamic Island — « O », compact | `GoLiveActivityView.swift:146-149` | #34C759 | `#000000` | `#34C759` | **9.46** | 4.5 | PASS |
| A49 | Dynamic Island — « N », compact | `GoLiveActivityView.swift:146-149` | #FF6B5B | `#000000` | `#FF6B5B` | **7.51** | 4.5 | PASS |
| A50 | Dynamic Island — spot name, compact | `GoLiveActivityView.swift:152-154` | #FFFFFF | `#000000` | `#FFFFFF` | **21.00** | 4.5 | PASS |
| A51 | Dynamic Island — « O »/« N », minimal | `GoLiveActivityView.swift:162-165` | #34C759 | `#000000` | `#34C759` | **9.46** | 4.5 | PASS |
| A52 | Dynamic Island — sand icon, compact/minimal | `GoLiveActivityView.swift:144, :160` | #F2E3C2 | `#000000` | `#F2E3C2` | **16.54** | 3.0 | PASS |

## 4. Table B — glass surfaces (modelled)

App cards, tiles, chips and pills at the audited 15 % white model (§2.4). `Margin` is the largest
white glass fill that still meets the row's threshold.

| # | Element | Source | Foreground | Background | Composite | Ratio | Threshold | Margin | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| B1 | AnswerCard — eyebrow « BON MOMENT POUR SORTIR ? » | `AnswerCard.swift:25-28` | #FFFFFF 70 % | `#2F5A7A` | `#C1CED7` | **4.55** | 4.5 | 15 % | PASS (marginal) |
| B2 | AnswerCard — « Oui » verdict | `AnswerCard.swift:36-38` | #34C759 | `#2F5A7A` | `#34C759` | **3.30** | 3.0 | 18 % | PASS (marginal) |
| B3 | AnswerCard — « Non » verdict | `AnswerCard.swift:36-38` | #FF6B5B | `#2F5A7A` | `#FF6B5B` | **2.62** | 3.0 | 10 % | **FAIL** |
| B4 | AnswerCard — « Indisponible » verdict | `AnswerCard.swift:36-38` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 3.0 | 38 % | PASS |
| B5 | AnswerCard — « Oui » icon | `AnswerCard.swift:31-33` | #34C759 | `#2F5A7A` | `#34C759` | **3.30** | 3.0 | 18 % | PASS (marginal) |
| B6 | AnswerCard — « Non » icon | `AnswerCard.swift:31-33` | #FF6B5B | `#2F5A7A` | `#FF6B5B` | **2.62** | 3.0 | 10 % | **FAIL** |
| B7 | AnswerCard — reason line | `AnswerCard.swift:42-44` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B8 | AnswerCard — tide detail line | `AnswerCard.swift:48-50` | #FFFFFF 85 % | `#2F5A7A` | `#E0E6EB` | **5.83** | 4.5 | 25 % | PASS (marginal) |
| B9 | LoadingCard — text | `HomeView.swift:142-144` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B10 | LoadingCard — ProgressView (accent tint) | `HomeView.swift:141` | #30D5C8 | `#2F5A7A` | `#30D5C8` | **4.01** | 3.0 | 25 % | PASS (marginal) |
| B11 | UnavailableCard — eyebrow | `HomeView.swift:161-164` | #FFFFFF 70 % | `#2F5A7A` | `#C1CED7` | **4.55** | 4.5 | 15 % | PASS (marginal) |
| B12 | UnavailableCard — icon | `HomeView.swift:167-169` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 3.0 | 38 % | PASS |
| B13 | UnavailableCard — « Données indisponibles » | `HomeView.swift:171-173` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 3.0 | 38 % | PASS |
| B14 | UnavailableCard — message | `HomeView.swift:177-179` | #FFFFFF 85 % | `#2F5A7A` | `#E0E6EB` | **5.83** | 4.5 | 25 % | PASS (marginal) |
| B15 | SwimmingAdvisoryCard — eyebrow « BAIGNADE » | `SwimmingAdvisoryCard.swift:16-19` | #FFFFFF 70 % | `#2F5A7A` | `#C1CED7` | **4.55** | 4.5 | 15 % | PASS (marginal) |
| B16 | SwimmingAdvisoryCard — alert icon | `SwimmingAdvisoryCard.swift:22-24` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 3.0 | 38 % | PASS |
| B17 | SwimmingAdvisoryCard — warning | `SwimmingAdvisoryCard.swift:27-29` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B18 | SwimmingAdvisoryCard — conditions line | `SwimmingAdvisoryCard.swift:34-36` | #FFFFFF 85 % | `#2F5A7A` | `#E0E6EB` | **5.83** | 4.5 | 25 % | PASS (marginal) |
| B19 | SwimmingAdvisoryCard — blocker icon | `SwimmingAdvisoryCard.swift:42-44` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 3.0 | 38 % | PASS |
| B20 | SwimmingAdvisoryCard — blockers in words | `SwimmingAdvisoryCard.swift:46-48` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B21 | SwimmingAdvisoryCard — level « faibles » | `SwimmingAdvisoryCard.swift:56-58` | #30D5C8 | `#2F5A7A` | `#30D5C8` | **4.01** | 4.5 | 11 % | **FAIL** |
| B22 | SwimmingAdvisoryCard — level « modérés » | `SwimmingAdvisoryCard.swift:56-58` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B23 | SwimmingAdvisoryCard — level « forts » | `SwimmingAdvisoryCard.swift:56-58` | #FF6B5B | `#2F5A7A` | `#FF6B5B` | **2.62** | 4.5 | 0 % | **FAIL** |
| B24 | SwimmingAdvisoryCard — level « non estimés » | `SwimmingAdvisoryCard.swift:56-58` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B25 | NextWindowCard — header, window state | `NextWindowCard.swift:22-24` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B26 | NextWindowCard — header, unavailable state | `NextWindowCard.swift:22-24` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B27 | NextWindowCard — window or message | `NextWindowCard.swift:27-40` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B28 | NextWindowCard — next window | `NextWindowCard.swift:44-46` | #FFFFFF 80 % | `#2F5A7A` | `#D5DEE4` | **5.38** | 4.5 | 22 % | PASS (marginal) |
| B29 | ConditionTile — icon | `ConditionsGrid.swift:61-63` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 3.0 | 38 % | PASS |
| B30 | ConditionTile — value | `ConditionsGrid.swift:65-67` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B31 | ConditionTile — label | `ConditionsGrid.swift:69-71` | #FFFFFF 75 % | `#2F5A7A` | `#CBD6DE` | **4.95** | 4.5 | 19 % | PASS (marginal) |
| B32 | TipCard — « sparkles » icon | `TipCard.swift:14-16` | #30D5C8 | `#2F5A7A` | `#30D5C8` | **4.01** | 3.0 | 25 % | PASS (marginal) |
| B33 | TipCard — « Conseil » | `TipCard.swift:20-22` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B34 | TipCard — tip body | `TipCard.swift:23-25` | #FFFFFF 90 % | `#2F5A7A` | `#EAEFF2` | **6.31** | 4.5 | 27 % | PASS |
| B35 | ActivitySegmentedControl — unselected chip | `ActivitySegmentedControl.swift:96-110` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B36 | ActivitySegmentedControl — unselected chip glyph | `ActivitySegmentedControl.swift:101-107` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 3.0 | 47 % | PASS |
| B37 | ActivitySegmentedControl — Menu label (AX1+) | `ActivitySegmentedControl.swift:68-75` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B38 | ActivitySegmentedControl — selected white pill | `ActivitySegmentedControl.swift:110` | #06223F | `#DFE1E3` | `#06223F` | **12.24** | 4.5 | n/a | PASS |
| B39 | ActivitySegmentedControl — selected pill glyph | `ActivitySegmentedControl.swift:110` | #06223F | `#DFE1E3` | `#06223F` | **12.24** | 3.0 | n/a | PASS |
| B40 | SpotButton — pin icon | `SmallComponents.swift:30-31` | #30D5C8 | `#2F5A7A` | `#30D5C8` | **4.01** | 3.0 | 25 % | PASS (marginal) |
| B41 | SpotButton — spot name | `SmallComponents.swift:32-34` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B42 | SpotSwitcher — unselected chip | `SpotSwitcher.swift:69-74` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B43 | SpotSwitcher — « circle » glyph | `SpotSwitcher.swift:66-68` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 3.0 | 47 % | PASS |
| B44 | SpotSwitcher — selected chip | `SpotSwitcher.swift:74` | #06223F | `#DFE1E3` | `#06223F` | **12.24** | 4.5 | n/a | PASS |
| B45 | SpotSwitcher — Menu label (AX3+) | `SpotSwitcher.swift:103-109` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B46 | AlertsView — « Me prévenir 1 h avant » | `AlertsView.swift:70-72` | #FFFFFF | `#2F5A7A` | `#FFFFFF` | **7.33** | 4.5 | 32 % | PASS |
| B47 | AlertsView — setting subtitle | `AlertsView.swift:73-75` | #FFFFFF 75 % | `#2F5A7A` | `#CBD6DE` | **4.95** | 4.5 | 19 % | PASS (marginal) |
| B48 | AlertsView — « Notifications désactivées » | `AlertsView.swift:90-92` | #F2E3C2 | `#2F5A7A` | `#F2E3C2` | **5.78** | 4.5 | 23 % | PASS (marginal) |
| B49 | AlertsView — denial body | `AlertsView.swift:93-95` | #FFFFFF 85 % | `#2F5A7A` | `#E0E6EB` | **5.83** | 4.5 | 25 % | PASS (marginal) |
| B50 | AlertsView — button « Ouvrir les réglages » | `AlertsView.swift:97-103` | #30D5C8 | `#2F5A7A` | `#30D5C8` | **4.01** | 4.5 | 11 % | **FAIL** |

## 5. Table C — not verifiable

These pairs are rendered by the app, but their backdrop is **MapKit raster content**
(`SpotsView.swift:18-29`, a standard-style map that follows the dark appearance) or a **system
surface**. The ratio shown is what the pair would score if the backdrop were the app gradient
with a glass card over it; it is the best case, not a measurement, so it is not a verdict.

| # | Element | Source | Foreground | Ratio if the backdrop were the gradient (best case) | Threshold | Verdict |
|---|---|---|---|---|---|---|
| C1 | SpotsView — spot name | `SpotsView.swift:60-62` | #FFFFFF | **7.33** | 4.5 | NOT VERIFIABLE |
| C2 | SpotsView — window range | `SpotsView.swift:76-78` | #FFFFFF 85 % | **5.83** | 4.5 | NOT VERIFIABLE |
| C3 | SpotsView — « Créneaux indisponibles » | `SpotsView.swift:71-73` | #F2E3C2 | **5.78** | 4.5 | NOT VERIFIABLE |
| C4 | SpotsView — swimming warning | `SpotsView.swift:100-102` | #FFFFFF | **7.33** | 4.5 | NOT VERIFIABLE |
| C5 | SpotsView — swimming conditions | `SpotsView.swift:105-107` | #FFFFFF 85 % | **5.83** | 4.5 | NOT VERIFIABLE |
| C6 | SpotsView — swimming blockers | `SpotsView.swift:111-113` | #F2E3C2 | **5.78** | 4.5 | NOT VERIFIABLE |
| C7 | SpotsView — swimming disclaimer | `SpotsView.swift:117-119` | #FFFFFF 70 % | **4.55** | 4.5 | NOT VERIFIABLE |
| C8 | SpotsView — « Données indisponibles » | `SpotsView.swift:137-139` | #F2E3C2 | **5.78** | 4.5 | NOT VERIFIABLE |
| C9 | SpotsView — unavailable message | `SpotsView.swift:140-142` | #FFFFFF 75 % | **4.95** | 4.5 | NOT VERIFIABLE |
| C10 | VerdictBadge — « Oui » | `SmallComponents.swift:53-55` | #34C759 | **3.30** | 4.5 | NOT VERIFIABLE |
| C11 | VerdictBadge — « Non » | `SmallComponents.swift:53-55` | #FF6B5B | **2.62** | 4.5 | NOT VERIFIABLE |
| C12 | VerdictBadge — « Indisponible » | `SmallComponents.swift:53-55` | #F2E3C2 | **5.78** | 4.5 | NOT VERIFIABLE |
| C13 | SwimmingRiskBadge — « faibles » | `SmallComponents.swift:66-68` | #30D5C8 | **4.01** | 4.5 | NOT VERIFIABLE |
| C14 | SwimmingRiskBadge — « modérés » | `SmallComponents.swift:66-68` | #F2E3C2 | **5.78** | 4.5 | NOT VERIFIABLE |
| C15 | SwimmingRiskBadge — « forts » | `SmallComponents.swift:66-68` | #FF6B5B | **2.62** | 4.5 | NOT VERIFIABLE |
| C16 | SwimmingRiskBadge — « non estimés » | `SmallComponents.swift:66-68` | #F2E3C2 | **5.78** | 4.5 | NOT VERIFIABLE |

The map is the one surface where the design cannot guarantee contrast at all: the visible region
changes with the spot, and a light coastline, a road label or a POI-free landmass moves the glass
card's sampled colour. `spotCard` and the two badges it hosts (C10–C16) need either an opaque card
background or an on-device measurement before M3 can be signed off.

Also not verifiable, and why:

| Surface | Why |
| --- | --- |
| Tab bar (`RootView.swift:14-27`, tint `#30D5C8`) | System Liquid Glass chrome; the selected-label colour and the bar material are rendered by the system |
| Navigation bar / large title (`SettingsView.swift:57-58`) | System chrome; the bar material changes with scroll offset |
| `Menu` items (`ActivitySegmentedControl.swift:46-66`, `SpotSwitcher.swift:87-99`) | System popover background |
| `Toggle` (`AlertsView.swift:68-79`) | System switch; `tint` only sets the on-state track |
| `ProgressView` on the map (`SpotsView.swift:147`) | Over the map raster |
| Map marker (`SpotsView.swift:19-23`) | Rendered over the map raster |
| Reduce Transparency fallback (`GlassStyles.swift:25-33`) | Not implemented: the modifier reads no environment value, so there is no opaque surface to measure. `ARCHITECTURE_PLAN.md` §12.3 and M6 require one; until it exists the glass pairs above are the only rendering |

## 6. Failures and minimum corrections

Six pairs fail. Each correction below is the **smallest** change that reaches the threshold on
that surface, computed by bisection: the hex is the same hue scaled toward white until the ratio
hits the threshold exactly. No pair is fixed by an opacity change alone, because every failing
foreground is already fully opaque.

| # | Element | Ratio | Threshold | Minimum opacity | Minimum hex | Ratio of the fix |
|---|---|---|---|---|---|---|
| A20 | GoWidget — « Courants : forts » | 4.04 | 4.5 | n/a (opaque) | `#FF7C6E` | 4.50 |
| B3 | AnswerCard — « Non » verdict | 2.62 | 3.0 | n/a (opaque) | `#FF8072` | 3.00 |
| B6 | AnswerCard — « Non » icon | 2.62 | 3.0 | n/a (opaque) | `#FF8072` | 3.00 |
| B21 | SwimmingAdvisoryCard — level « faibles » | 4.01 | 4.5 | n/a (opaque) | `#5DDED4` | 4.50 |
| B23 | SwimmingAdvisoryCard — level « forts » | 2.62 | 4.5 | n/a (opaque) | `#FFBAB2` | 4.50 |
| B50 | AlertsView — button « Ouvrir les réglages » | 4.01 | 4.5 | n/a (opaque) | `#5DDED4` | 4.50 |

**A20 — `GoWidget` « Courants : forts », `GoWidget.swift:97-99`, 4.04:1 (needs 4.5:1).**
`non` `#FF6B5B` at 11 pt on the widget gradient. Minimum fix: `#FF7C6E` (4.50:1). This one is
independent of the glass model and must be fixed whatever the rendering turns out to be.

**B3/B6 — `AnswerCard` « Non » and its pictogram, `AnswerCard.swift:31-38`, 2.62:1 (needs 3:1).**
`non` at 76 pt bold. Minimum fix: `#FF8072` (3.00:1); `#FF8F82` gives 3.32:1 with headroom. Note
the root cause: at 0 % glass fill the pair is 4.04:1, which still passes 3:1, so the verdict
depends entirely on the glass being darker than 10.4 % white. The cheapest fix that keeps the
palette is not a hex change but a darker card; the cheapest fix that keeps the card is a lighter
coral.

**B21 — swimming level « faibles », `SwimmingAdvisoryCard.swift:56-58`, 4.01:1 (needs 4.5:1).**
`turquoise` `#30D5C8` at 13 pt. Minimum fix: `#5DDED4` (4.50:1).

**B23 — swimming level « forts », `SwimmingAdvisoryCard.swift:56-58`, 2.62:1 (needs 4.5:1).**
`non` at 13 pt. Minimum fix: `#FFBAB2` (4.50:1) — a pale coral that is very close to `sand`
`#F2E3C2` in value, so the level would lose its colour distinction from the « modérés » level.
Two cheaper-looking fixes, and why neither works:
- keep `#FF6B5B` and move the level label out of the glass card onto the bare gradient, where it
  is 4.04:1 — still short of 4.5:1, so this does not work either;
- treat the coral as an icon/large-text colour only and set the 13 pt label in `white`, with the
  coral carried by the `exclamationmark.triangle.fill` glyph at ≥ 3:1 (which the coral only meets
  below 10.4 % glass fill).

So `non` is the one colour in the palette that reaches 4.5:1 as text on **no** scrolling screen:
it needs a backdrop darker than `L = 0.0334`, and the gradient only drops below that past its
first ~18 % from the top. The Live Activity (`#031426`, 6.63:1) and the Dynamic Island
(`#000000`, 7.51:1) do clear it, so the colour stays usable — just not as text on a glass card.
A text variant of the coral is the only clean fix; `#FFBAB2` is the minimum, `#FFC4BD` (4.85:1)
gives headroom.

**B50 — « Ouvrir les réglages », `AlertsView.swift:97-103`, 4.01:1 (needs 4.5:1).** `turquoise` at
13 pt semibold, same colour as B21, same minimum fix `#5DDED4`. The button is also the only
control on that screen, so a darker backdrop is not an option: it sits on a glass card.

## 7. Marginal passes

These 22 pairs, grouped by identical foreground/background pair, pass at the audited
15 % model but fail once the glass is at 25 % white.
They are not failures today; they are the pairs that will fail silently if the glass gets lighter,
if a Figma fill is applied, or if `Reduce Transparency` lands with a bright opaque surface.

| Pair | Ratio at 15 % | Margin (breaks above) | Ratio at 25 % |
| --- | --- | --- | --- |
| white 70 % on glass — the three card eyebrows (`AnswerCard`, `UnavailableCard`, `SwimmingAdvisoryCard`) | 4.55 | 15.4 % | 3.60 |
| white 75 % on glass — tile label, alerts subtitle | 4.95 | 18.9 % | 3.88 |
| white 80 % on glass — next-window secondary | 5.38 | 22.0 % | 4.17 |
| white 85 % on glass — conditions lines, card messages | 5.83 | 24.8 % | 4.47 |
| `sand` on glass — blockers, headers, « Indisponible » | 5.78 | 23.5 % | 4.31 |
| `oui` 76 pt on glass — « Oui » verdict (3:1) | 3.30 | 18.2 % | 2.46 |
| `turquoise` 17 pt on glass — icons (3:1) | 4.01 | 24.9 % | 2.99 |

White 70 % is the one to watch: 4.55:1 leaves 0.4 points of margin against the model. It is used
seven times: three on glass (`AnswerCard.swift:28`, `HomeView.swift:164`,
`SwimmingAdvisoryCard.swift:19`), one on the map card (`SpotsView.swift:119`, unverifiable), and
three on exact backgrounds that pass with headroom (`GoWidget.swift:70`, `GoWidget.swift:103`,
`GoLiveActivityView.swift:87`).

## 8. Glass model sensitivity

Ratio of each foreground over the top gradient end with a white glass fill from 0 % to 30 %.
Row `15 %` is the audited model.

| White glass fill | Backdrop | white 100 % | white 85 % | white 80 % | white 75 % | white 70 % | sand | turquoise | oui | non | unavailable |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 % | `#0A3D62` | 11.31 | 8.63 | 7.83 | 7.08 | 6.38 | 8.91 | 6.18 | 5.09 | 4.04 | 8.91 |
| 5 % | `#16476A` | 9.83 | 7.61 | 6.94 | 6.32 | 5.73 | 7.74 | 5.37 | 4.43 | 3.51 | 7.74 |
| 10 % | `#225072` | 8.50 | 6.67 | 6.12 | 5.60 | 5.11 | 6.70 | 4.65 | 3.83 | 3.04 | 6.70 |
| 15 % | `#2F5A7A` | 7.33 | 5.83 | 5.38 | 4.95 | 4.55 | 5.78 | 4.01 | 3.30 | 2.62 | 5.78 |
| 20 % | `#3B6481` | 6.32 | 5.10 | 4.73 | 4.38 | 4.04 | 4.98 | 3.46 | 2.85 | 2.26 | 4.98 |
| 25 % | `#476E89` | 5.47 | 4.47 | 4.17 | 3.88 | 3.60 | 4.31 | 2.99 | 2.46 | 1.95 | 4.31 |
| 30 % | `#547791` | 4.74 | 3.93 | 3.68 | 3.45 | 3.22 | 3.73 | 2.59 | 2.14 | 1.69 | 3.73 |

The `oui` and `non` rows show why the accent palette is the fragile part of this design: at
30 % glass fill the coral is 1.69:1, which is not text at all. If the shipped glass turns out to
be lighter than ~10 %, the giant « Non » is the first casualty and the fix is a palette token, not
a layout change.

## 9. Not audited / assumptions

**Not audited, by design.**

- `blueGlow` `#0091FF`, `ouiDark` `#03210F`, `glassTint` `#BFD9FF`, `segmentedBackground`
  `#767680`, `chartHighlight` `#30D158` and `navyInk` `#06223F` are declared in
  `OceanPalette.swift:8-18` and **referenced by no view**. They are not rendered, so they are not
  audited. `navyInk` and `ink` are the same value; only `ink` is used.
- The `Divider` in `SwimmingAdvisoryCard.swift:53-54` (`white 20 %`) is decorative: it carries no
  information, so WCAG 1.4.11 does not apply. Its ratio is 1.52:1 on glass and it should not be
  used as a separator that conveys grouping.
- Focus rings, hover, pressed and disabled states: SwiftUI does not expose them as colours, and
  none of the views sets a disabled style.
- The `#30D5C8` / `#0091FF` blurred glow ellipses from `DESIGN_REFERENCE.md` §1 are **not
  implemented** (no `blur` or glow shape exists in `Estran/`). If they are added later, they raise
  the backdrop luminance locally and every glass pair in table B must be recomputed — the
  sensitivity table in §8 is the tool for that.
- Reduce Transparency, Increase Contrast, Bold Text and Differentiate Without Colour are M6
  gates and are not implemented (`GlassStyles.swift` reads no environment value).

**Assumptions, all explicit.**

1. The glass fill is 15 % white over the backdrop (§2.4). **This is the only invented number in
   the report** and it drives every glass verdict. It is bracketed in §8 and each row carries its
   own breaking point, so no verdict depends on it silently.
2. `activityBackgroundTint(OceanPalette.oceanDeepBottom)` renders the Live Activity background as
   opaque `#031426`. Apple applies it as a tint over the activity's own background; an opaque
   colour is treated as opaque here. If the system composites it translucently over a light
   wallpaper, every Live Activity ratio drops and must be re-measured.
3. The Dynamic Island background is `#000000` (it is opaque black on iPhone).
4. `.secondary` in `SettingsView.swift:19-21, :32, :41, :51` is `UIColor.secondaryLabel` in dark
   mode, i.e. white at 60 % alpha. It is marked † in table A because it is a **derived** system
   value, not a palette entry; the row reads 5.13:1, which is the same as an explicit white 60 %.
5. 1 pt = 1 CSS px for the large-text comparison, and semibold is not bold (§2.5). Both choices
   are conservative.
6. The screens use the dark appearance only: `RootView.swift:31` forces
   `.preferredColorScheme(.dark)` and the palette has no light variant. No light-mode pair exists
   to audit, and none should be proposed.
7. Cards are assumed to sample the backdrop directly behind them, with no intervening content.
   A glass card that overlaps another glass card (`GlassEffectContainer` in `HomeView.swift:20-28`
   merges the segmented control and the answer card) would sample a lighter surface; the 15 %
   model is the conservative stand-in.
8. Text is assumed to render with the palette colour at full sRGB and no vibrancy. SwiftUI applies
   vibrancy to some system materials; none is used here.

## 10. What this audit does not settle

- It does not replace an on-device measurement. The glass model in §2.4 is the largest single
  uncertainty, and one screenshot sampled with a colour picker over the answer card would collapse
  it to a fact.
- It does not cover the Figma match, Dynamic Type AX5, VoiceOver or the 44 × 44 pt gate — the
  other open M3 criteria.
- It does not audit `MapKit` raster contrast, which is the one place where the product cannot
  guarantee its own numbers (§5).

## Lead review and remediation (2026-10-28, after this audit)

The audit models the glass at 15 % white. The real render was sampled from a
simulator screenshot of Home (`628 × 2622`, 3× scale): the answer card is
`#19476A` (relative luminance `0.0575`), the bare gradient top `#1D5783`
(`0.0872`) and the bottom `#09385A` (`0.0362`). Recomputing the four glass rows
that carry a verdict:

| Row | Modelled | Measured on the render | Effect |
|---|---|---|---|
| B3/B6 — « Non » verdict + icon | 2.62 (FAIL at 3:1) | **3.49** | passes at 3:1 with headroom → the vivid `#FF6B5B` stays on the 76 pt badge |
| B21 — level « faibles » (turquoise) | 4.01 (FAIL at 4.5:1) | **5.34** | passes; the token is still applied for headroom |
| B23 — level « forts » (coral, 13 pt) | 2.62 (FAIL at 4.5:1) | **3.49** | still under 4.5:1 as small text → fixed by token |
| B50 — « Ouvrir les réglages » (turquoise) | 4.01 (FAIL at 4.5:1) | **5.34** | passes; token applied for consistency |
| A20 — widget « Courants : forts » | 4.04 (FAIL at 4.5:1) | exact background, model-independent | fixed by token |

Corrections shipped, none of them a palette redesign:

1. `OceanPalette.nonOnGlass` (`#FFBAB2`, 4.50:1 at the audit's 15 % glass,
   6.0:1 on the measured card) and `OceanPalette.turquoiseOnGlass`
   (`#5DDED4`, 4.50:1 / 5.9:1). Same hues, lifted.
2. `OceanPalette.swimmingRiskText(_:)` is the text scale; `swimmingRisk(_:)`
   stays the vivid Figma scale for glyphs and for the opaque Live Activity
   background (`#031426`, where the vivid coral already clears 4.5:1 at 6.63:1).
3. `VerdictState.badgeColor` for `VerdictBadge` (17 pt on glass); the giant
   `AnswerCard` verdict keeps `VerdictState.color`.
4. Applied at `SwimmingAdvisoryCard` (level), `SmallComponents`
   (`VerdictBadge`, `SwimmingRiskBadge`), `AlertsView` (« Ouvrir les réglages »)
   and `GoWidget` (« Courants : … »).

Still open: the glass is translucent and sits over a map on `SpotsView`, so its
rendered luminance varies with the map tiles. Table C stays **NOT VERIFIABLE**
until a pixel sample is taken per state on a device; the text tokens above give
every one of those pairs the same worst-case margin.
