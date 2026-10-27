# Estran

On-device iOS app that answers **Oui / Non** for five coastal activities on the
Médoc and Bassin coast. The full product and architecture source of truth is
[`ARCHITECTURE_PLAN.md`](ARCHITECTURE_PLAN.md); the UI source of truth is
[`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md).

## Status

**M0 — Setup** and **M1 — Domain core** are implemented. The repository contains
the XcodeGen project definition, the two product targets (`Estran`,
`EstranWidgets`), the `EstranCore` package, the App Group entitlements, the
decision engine, and the embedded REFMAR-derived tide dataset
(`tide-model-2026.1.json`, schema 6: 3 stations × 25 constituents, 2 gauged
spots).

**M3 — UI** is in progress: the four-tab shell, Home on DEBUG demo data, the
2-spot focus map, the alerts opt-in and the settings attribution screen are
written. The app target has **not been compiled on macOS yet** — no Xcode/Apple
SDK on the current Linux host. `EstranCore` and the non-UI app layer are
type-checked; the SwiftUI layer is syntax-parsed only.

Release-relevant state:

- baignade is a risk level computed from the **local predicted tidal range**
  (`swimmingRange`), never a « Oui »; the national Brest coefficient is
  computed but not validated and not displayed;
- `validUntil` is **2029** for all stations; the dataset is regenerated once a
  year as a maintenance ritual (`BUILD.md`), not as a product expiry;
- Linux package checks: **164 tests, 0 failures**; SwiftFormat lint clean.

## Requirements

- macOS with Xcode 26+ and the iOS 27 SDK;
- [XcodeGen](https://github.com/yonaskolb/XcodeGen);
- SwiftLint and SwiftFormat for style checks;
- Swift 6 for the Linux `EstranCore` package checks.

## Generate and build

```sh
xcodegen generate
open Estran.xcodeproj
```

The generated `.xcodeproj` and `.xcworkspace` are intentionally ignored; edit
`project.yml` and regenerate.

Command-line checks:

```sh
./scripts/check-linux.sh
./scripts/check-macos.sh
./scripts/check-macos.sh --archive
```

## Layout

```
Estran/                 App target (SwiftUI presentation + theme + resources)
EstranWidgets/          WidgetKit extension, Live Activity, Dynamic Island
Packages/EstranCore/    Shared domain models and SwiftData persistence baseline
EstranTests/            App-level unit-test bundle
EstranUITests/          UI-test bundle
project.yml             XcodeGen definition for the two product targets
scripts/                Reproducible local checks
.github/workflows/      Linux package checks and macOS build/test/archive checks
```

Product targets: exactly `Estran` and `EstranWidgets`. `EstranTests` and
`EstranUITests` are test bundles.

## Identifiers

- App bundle: `com.forgedigitale.estran`
- Widget extension: `com.forgedigitale.estran.widgets`
- App Group: `group.com.forgedigitale.estran`

No secret, API key, signing certificate, or provisioning profile is committed.
WeatherKit is expected to use the app's signing entitlement from M2 onward.

## Validation status

`EstranCore` was built and tested on Linux with Swift 6.0.3: `swift build` and
`swift test` pass (3 tests). SwiftFormat lint passes on the checked-in Swift
sources. `xcodegen generate` also passes with XcodeGen 2.46.0 built from source
on Linux; the generated project contains the two product targets, the two test
bundles, the local `EstranCore` package, the embedded widget extension, and the
expected entitlement/plist settings.

The host has no Xcode or Apple SDK, so every Apple-platform build, test, archive,
SwiftLint, and entitlement/provisioning check remains **pending** until it is
run on a compatible macOS host or in CI. Their configuration being present is
not evidence that they passed.
