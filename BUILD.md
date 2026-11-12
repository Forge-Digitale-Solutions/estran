# Build, ship and maintain

Everything that must happen on **Anthony's Mac**. None of it can run on the Linux development host: it has no Apple SDK, so `swift build` / `swift test` only ever cover `EstranCore`.

Last reviewed: 2026-10-27 (iOS 27 target, Xcode 26/27, paid Apple Developer Program).

## Requirements

- macOS with Xcode 26+ and the iOS 27 SDK (app, widgets, Live Activity);
- [XcodeGen](https://github.com/yonaskolb/XcodeGen);
- SwiftLint and SwiftFormat;
- Swift 6 and Python 3.11+ for the Linux package checks and the tide generator.

| Item | State |
|---|---|
| Apple Developer Program (paid) | ✅ available — required for App Store, TestFlight, App Group, WeatherKit |
| Mac with Xcode | ✅ available |
| Development host | Linux — cannot compile the app, the widget or the intents |
| Bundle IDs | app `com.forgedigitalesolutions.estran`, widget `com.forgedigitalesolutions.estran.widgets` |
| App Group | `group.com.forgedigitalesolutions.estran` |
| Deployment target | iOS 27.0, iPhone only (`TARGETED_DEVICE_FAMILY = 1`) |
| Swift | 6.0, `SWIFT_STRICT_CONCURRENCY = complete` |

Three build checkpoints only (see `ARCHITECTURE_PLAN.md` §16.1): M3 close, M5 close, pre-TestFlight.

## Local checks

```sh
./scripts/check-linux.sh     # EstranCore build + tests (Linux)
./scripts/check-macos.sh     # XcodeGen, xcodebuild build/test, lint (macOS)
./scripts/check-macos.sh --archive
```

**CI scope.** GitHub Actions covers the Linux package, both linters, an unsigned
archive and a macOS **build**. It does **not** run the unit/UI tests: the
hosted images still ship Xcode 26.6 (checked 2026-11-02), with no iOS simulator
runtime and a `downloadPlatform` that fails with « Unable to connect to
simulator ». Tests are the local gate (`check-macos.sh`), and the CI job gets its
test step back the day a runner image carries Xcode 27.

`check-linux.sh` does **not** compile the SwiftUI app target: there is no Apple
SDK on the Linux host. The app is syntax-parsed and the non-UI layer is
type-checked; the macOS gates stay explicitly pending until `check-macos.sh`
has actually run.

**Real data in the simulator.** Debug builds use the demo provider unless the app
is launched with `-liveData`:

```sh
xcrun simctl launch "iPhone 18 Pro" com.forgedigitalesolutions.estran -liveData
```

The live path needs the WeatherKit capability (§1.3): without it the app stops at
« La météo n'est pas encore disponible pour ce spot », which is the fail-closed
path, not a bug. Open-Meteo Marine (waves, sea temperature) needs no key and no
capability.

**Simulator runtime after an Xcode update.** `xcodebuild test` can abort with
« The iOS <version> simulator runtime is not available » even though the build
works. Check `xcrun simctl list runtimes`: when it prints no runtime, the
disk image is present but unmounted (`xcrun simctl runtime list` still shows it).
`check-macos.sh` boots the device first, which covers the common cold-start case;
a fully unregistered runtime needs Xcode → **Settings → Components → iOS
<version>** (re-download), or:

```sh
xcodebuild -downloadPlatform iOS
```

---

## 1. One-time portal setup (developer.apple.com)

Do this **before** the first build, otherwise Xcode cannot register the App Group and the capability checks fail.

1. **Certificates, Identifiers & Profiles → Identifiers → App IDs** — create two explicit App IDs (not a wildcard):
   - `com.forgedigitalesolutions.estran`
   - `com.forgedigitalesolutions.estran.widgets`
2. On **both** App IDs, enable **App Groups** and create/attach `group.com.forgedigitalesolutions.estran`.
3. On `com.forgedigitalesolutions.estran`, enable **WeatherKit**. No push capability is needed: Live Activity is updated locally, not by APNs.
4. **Users and Access** — make sure your role is Admin or App Manager (needed to create the App record and upload builds).

## 2. First clone and build

```bash
git clone <repo> estran && cd estran
brew install xcodegen && xcodegen generate
open Estran.xcodeproj
```

`Estran.xcodeproj` is generated from `project.yml` and is **git-ignored**. Regenerate it after every `project.yml` change; never edit it by hand.

Then, for **each of the four targets** (`Estran`, `EstranWidgets`, `EstranTests`, `EstranUITests`):

- *Signing & Capabilities* → Team = your team, *Automatically manage signing*.
- `Estran` and `EstranWidgets` → *+ Capability* → App Groups → check `group.com.forgedigitalesolutions.estran`.
- `Estran` → *+ Capability* → WeatherKit.

Command line equivalent for a quick compile check:

```bash
xcodebuild -project Estran.xcodeproj -scheme Estran \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build
```

To run: pick an iPhone simulator and ⌘R. In DEBUG the app uses `DemoConditionsProvider` (real tide model, synthetic weather) and shows the *Données d'exemple* badge. In Release it uses `LiveConditionsProvider`, which refuses until M2 ships the weather pipeline — that is intended, not a bug.

## 3. First-build failures

The first macOS build ran on 2026-10-28 with Xcode 27.1 / iOS 27 (iPhone 18
Pro simulator). It exposed one real error and one test fixture gap:

- the asset catalog required an `AppIcon` set (an interim generated icon now
  ships — replace it with the final asset, §4);
- the UI test looked for `app.title`, which did not exist; the Home title now
  carries that accessibility identifier;
- SwiftLint's `opening_brace` conflicted with SwiftFormat's
  `wrapMultilineStatementBraces`, and ten genuine lint findings (complexity,
  type-body length, a large tuple, two IUOs) were cleaned up. Both linters now
  pass with `--strict`.

Keep the four families below in mind when a new target (widget, intents) is
compiled for the first time:

1. **Swift 6 strict concurrency** — `Sendable` across actor boundaries, `@MainActor` isolation on view models, `TideEngine` captured by a task. Fix at the API boundary, do not add `@unchecked Sendable` to silence it.
2. **iOS 27 API surface** — the exact `glassEffect(_:in:)` signature, `GlassEffectContainer`, `.buttonStyle(.glass)`, `ControlWidget`. Confirm against the SDK; keep the availability branch in the theme layer.
3. **Missing or misnamed symbols** between `EstranCore` and the app (the app is not built by the package tests, so a rename can slip through).
4. **Entitlements / signing** — App Group not registered, team not set on the widget extension.

Do not "fix" a compile error by deleting an accessibility modifier, a `fixedSize` or an `@ScaledMetric`: those are release gates (`DESIGN_REFERENCE.md` §2.1, `ARCHITECTURE_PLAN.md` §13).

**Signing trap.** A simulator build made with `CODE_SIGNING_ALLOWED=NO` has no
App Group entitlement, and the SwiftData container traps at launch
(« Unable to find App Group Container in Entitlements »). Build and run with
the normal signing settings (`check-macos.sh` does). Keep
`CODE_SIGNING_ALLOWED=NO` for the archive-only check, which never launches.

## 4. Before TestFlight — assets and declarations

These are missing today and are **hard submission blockers**:

- [ ] **Final app icon.** An interim 1024×1024 `AppIcon.appiconset` was generated on 2026-10-28 so the build and archive can run (night-sea gradient, no alpha, no rounded corners). It is a placeholder: replace it with the final Figma export before TestFlight. App Store Connect rejects a build without a 1024×1024 icon.
- [ ] **Privacy manifest.** Add `Estran/PrivacyInfo.xcprivacy`:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>NSPrivacyTracking</key><false/>
      <key>NSPrivacyTrackingDomains</key><array/>
      <key>NSPrivacyCollectedDataTypes</key><array/>
      <key>NSPrivacyAccessedAPITypes</key>
      <array>
          <dict>
              <key>NSPrivacyAccessedAPIType</key>
              <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
              <key>NSPrivacyAccessedAPITypeReasons</key>
              <array><string>CA92.1</string></array>
          </dict>
      </array>
  </dict>
  </plist>
  ```
  (`CA92.1` = access to the app's own preferences. The App Group storage counts as the app's own data.)
- [x] **WeatherKit entitlement** in `Estran/Estran.entitlements` (`com.apple.developer.weatherkit`, `true`) — added 2026-11-02.
- [x] **WeatherKit capability on the App ID** (`com.forgedigitalesolutions.estran`) in the portal — registered 2026-11-12 (team D3UKXNVT3D) with App Groups, together with `com.forgedigitalesolutions.estran.widgets` and `group.com.forgedigitalesolutions.estran`. Still to do: sign with the team. Until then WeatherKit fails and the app falls back to Open-Meteo (logged), so it still answers; with neither source reachable it says « La météo n'est pas encore disponible pour ce spot » — the fail-closed path, not a crash.

  Note: the **WeatherKit REST API** is the server-side sibling (JWT signed with a private key). The app uses the native `WeatherKit` framework, which needs the capability and no key at all.
- [ ] **Privacy policy URL** — required even though the app collects nothing. A static French page is enough (GitHub Pages, 0 €). It must say: no account, no analytics, no data collection; attribution REFMAR/Shom — Licence Ouverte 2.0; weather from Apple WeatherKit and Open-Meteo.
- [ ] **App Privacy answers** in App Store Connect: *Data Not Collected*.
- [ ] **Version and build number** bumped (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`).

## 5. Archive and upload

```bash
xcodebuild -project Estran.xcodeproj -scheme Estran \
  -destination 'generic/platform=iOS' -configuration Release archive \
  -archivePath build/Estran.xcarchive
```

Then Xcode → *Organizer* → *Distribute App* → *App Store Connect* → *Upload*. Or:

```bash
xcodebuild -exportArchive -archivePath build/Estran.xcarchive \
  -exportPath build -exportOptionsPlist ExportOptions.plist
```

Wait for processing in App Store Connect, attach the build to the version, then TestFlight (internal testers first — yourself, one local of the Bassin, one of the Médoc).

## 6. App Review — what to put in the notes

The app gives **safety-relevant** advice about the sea. Two guidelines matter:

- **1.4.1 (physical harm).** State plainly in the review notes and in the description: the verdicts come from a local harmonic model computed from open REFMAR observations, they are **not** official SHOM predictions, and the app is a decision aid that does not replace official documents or local knowledge. The attribution is already in the UI (Home footer, Settings).
- **5.1.1 (data collection).** No account, no analytics, no third-party SDK, no server. Say so.

Also mention in the notes: the app is French-only by design, ships two spots (Arcachon-Eyrac and Pointe de Grave / Le Verdon), and baignade is presented as a **risk level** (« Courants estimés faibles / modérés / forts / non estimés »), never a « Oui », with a permanent warning and the sentence « L'app estime les courants de marée. Elle ne voit ni les baïnes, ni les maîtres-nageurs. » The level uses the calibrated local predicted range; a missing range is « Courants non estimés », and the national coefficient is not displayed.

---

## 7. Annual tide refresh ritual

The embedded tide dataset (`Packages/EstranCore/Sources/EstranCore/Resources/tide-model-2026.1.json`)
is a harmonic fit of REFMAR observations. It is **not** fetched at runtime and
it is **not** official.

Once a year, after the validated REFMAR year is published:

1. Run the generator (free, cached under `scripts/tides/.cache/`, git-ignored):

   ```sh
   python3 scripts/tides/refresh
   ```

2. Read `docs/data-sourcing/accuracy-2026.1.md`:
   - the held-out year must satisfy D2 (median |Δt| ≤ 12 min, p95 ≤ 35 min,
     |bias| ≤ 0.05 m, p95 |Δh| ≤ 0.40 m);
   - the **leave-one-year-out** worst `max(pred − obs)` must stay ≤ `u_h` − 0.05,
     and the worst `max |Δt|` must stay ≤ `u_t` − 10 (Z27/Z29);
   - **RMSE is a series property, not a single year** (Z30): the LOYO median
     must be ≤ 0.20 m and no LOYO year may exceed 0.22 m. A year at 0.21 m RMSE
     with a covered envelope is normal weather, not a regression (2023 is such a
     year at 190).
   - the generator aborts on an unexplained gap > 1.5 h, a datum step > 0.10 m,
     or a declared envelope that does not cover the measurement.
3. If the fit window rolls forward, the generator writes the new `validUntil`
   (fit end + 3 years) and the new `basis` strings.
4. Run `./scripts/check-linux.sh` and `./scripts/check-macos.sh`; `ShippedDatasetTests`
   fails if the shipped file is missing, expired, or violates the contract.
5. Commit the dataset and the report together. Never edit either by hand.

The horizon bounds **astronomical decay** (nodal drift, ±1.5 % over three
years), not annual weather dispersion: `u_h` carries that. A skipped year does
not brick the app, but the dataset should not age past `validUntil`.

## 8. Non-negotiables

- **No recurring cost except the Apple Developer Program membership**, which is held. Nothing else is purchased: no API key, no backend, no subscription, no paid licence.
- No API key is committed. The WFS key, if used, stays `<WFS_KEY>`.
- The model is « modèle local », never a SHOM prediction, never « mesure locale ».
- Baignade is **never a « Oui »**: it is a risk level (`SwimmingRiskLevel`) computed from the local predicted range (`swimmingRange`) with a permanent warning. A missing range is `Courants non estimés`; the national coefficient is not displayed.
- The coefficient is not displayed in v1.

## 9. Known limitations to state honestly

| Limitation | Why it is acceptable |
|---|---|
| 2 spots only | Both are backed by a gauge. A verdict is only issued where the model is validated. |
| Baignade is a risk level | The level uses the local predicted range, not a binary verdict. A missing range shows « Courants non estimés ». |
| No light mode | Dark-only by design (night-sea palette), forced at the root. |
| No push backend | 0 € constraint; Live Activity updates locally. |
| No marine currents | The free atlas cannot resolve the Bassin passes; the gate is conservative and can return unavailable. |
| Dataset expires in 2029 | `validUntil` fails closed. Refresh annually (§7); the horizon is a backstop, not the cadence. |
