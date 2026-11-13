# Estran

**« C'est un bon moment pour sortir ? »** — an on-device iOS 27 app that answers
**Oui / Non** for five coastal activities on the Bassin d'Arcachon and the Médoc.
French interface, no account, no server, no ads, no subscription.

🇫🇷 **[Version française](README.fr.md)**

---

## What it does

Pick an activity and one of the two spots — Arcachon-Eyrac or Pointe de Grave —
and get a verdict, plus the next good window and the four conditions that
produced it. The app never asks for your location: the two spots are fixed.

| | |
|---|---|
| **Activities** | pêche à pied · surf · bateau · balade · baignade |
| **Spots (v1)** | Arcachon-Eyrac (gauge 190) · Pointe de Grave / Le Verdon (gauge 15) |
| **Screens** | Maintenant · Spots (focus map) · Alertes · Réglages |

Two spots only, on purpose: a verdict is issued where the tide model is
validated against a real gauge. The 12 other coastal spots are a post-v1
roadmap, not a hidden catalog.

Everything is computed **on the device**:

- **tide** — a harmonic model fitted from open REFMAR observations, embedded as
  constants (no runtime tide API, works offline);
- **weather** — Apple WeatherKit (wind, temperature, precipitation,
  visibility);
- **swell** — Open-Meteo Marine (wave height and period).

No account, no analytics, no third-party SDK, no backend.

**Baignade is not a permission.** In the Bassin and on the Médoc coast the
water is dangerous all year, whatever the weather. Swimming is presented as a
**risk level** with a permanent warning about baïnes and tidal currents — never
a green « Oui ». Details in
[`ARCHITECTURE_PLAN.md` §7.3](ARCHITECTURE_PLAN.md).

## Status

| Milestone | State |
|---|---|
| **M0 — Setup** | done |
| **M1 — Domain core + tide dataset** | done — schema 6, 3 stations × 25 constituents, 2 gauged spots |
| **M2 — Weather** | **live sources operational** — WeatherKit and Open-Meteo Marine wired; the WeatherKit capability still to enable in the portal |
| **M3 — UI** | **iOS 27 visual pass shipped** — OceanBackdrop, Liquid Glass, zoom transition, tide scrub; device VoiceOver still open |
| **M4 — Intelligence** | **in progress** — Foundation Models (guarded generated sentence), Siri / Shortcuts, Spotlight, local notifications |
| **M5 — Widgets / Live Activity** | **built** — small/medium/large + Lock Screen families, real swimming level fed |

Release-relevant facts:

- `u_t` and `u_h` are per station and **leave-one-year-out** (worst year of the
  record, not one test year);
- the tide dataset is valid until **2029**; it is refreshed once a year as
  maintenance, not as a product expiry;
- the national Brest coefficient is computed but **not validated and not
  displayed**; it drives no safety decision;
- `EstranCore`: **165 tests, 0 failures**, SwiftFormat clean;
- first macOS build (2026-10-28, Xcode 27.1 / iOS 27): `xcodebuild` build,
  test and archive pass, SwiftLint and SwiftFormat clean, app launched on an
  iPhone 18 Pro simulator.

The M3 product gate is open on one point only: the device VoiceOver pass. M2
runs on the live sources; the WeatherKit capability still has to be enabled, and
the missing-sea case inside the Bassin is still to decide.

## Requirements

- macOS with Xcode 26+ and the iOS 27 SDK;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is
  generated from `project.yml` and is not committed;
- SwiftLint and SwiftFormat for style;
- Swift 6 for the Linux package checks.

## Build

```sh
brew install xcodegen
xcodegen generate
open Estran.xcodeproj
```

Checks:

```sh
./scripts/check-linux.sh          # EstranCore build + tests
./scripts/check-macos.sh          # XcodeGen, xcodebuild build/test, lint
./scripts/check-macos.sh --archive
```

Signing, App Group, WeatherKit capability and TestFlight are documented step by
step in [`BUILD.md`](BUILD.md).

## The tide model

The tide is not fetched at runtime. `scripts/tides/refresh` downloads REFMAR
observations (Licence Ouverte 2.0), runs a least-squares harmonic analysis on
25 constituents, runs QC, and writes the constants plus an accuracy report. The
app ships those constants and predicts locally.

Measured against the gauges on the held-out year (`docs/data-sourcing/accuracy-2026.1.md`):
RMSE ≈ 0.16 m, median event timing ≈ 10 min, p95 ≈ 32 min. The uncertainty
envelopes are sized on the worst year of the record, not on the average.

## Layout

```
Estran/                 App target (SwiftUI)
EstranWidgets/          WidgetKit extension, Live Activity, Dynamic Island
Packages/EstranCore/    Domain: models, tide engine, decision rules, dataset
EstranTests/            App-level unit tests
EstranUITests/          UI tests
scripts/                Local checks + tide generator
docs/                   Data sourcing and accuracy reports
project.yml             XcodeGen definition
```

## Documentation

| File | What it is |
|---|---|
| [`ARCHITECTURE_PLAN.md`](ARCHITECTURE_PLAN.md) | technical source of truth |
| [`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md) | UI spec extracted from the Figma file |
| [`BUILD.md`](BUILD.md) | build, signing, TestFlight, annual refresh |
| [`worksplit.md`](worksplit.md) | milestone contract and acceptance gates |
| [`review.md`](review.md) | the review history (blocking findings and their closure) |
| [`docs/data-sourcing/`](docs/data-sourcing/) | sourcing report and measured accuracy |

## Identifiers

- App: `com.forgedigitalesolutions.estran`
- Widget extension: `com.forgedigitalesolutions.estran.widgets`
- App Group: `group.com.forgedigitalesolutions.estran`

No secret, API key, certificate or provisioning profile is committed.

## Data & attribution

Tide observations: **REFMAR / Shom**, Licence Ouverte 2.0. The derived
constants are our own harmonic fit — « modèle local », never a SHOM prediction,
never « données officielles ». Weather: Apple WeatherKit. Waves: Open-Meteo.

## Licence

The source-code licence is **not decided yet**. The repository is private and no
licence file is provided; one must be chosen before making it public. The data
attribution above applies regardless.
