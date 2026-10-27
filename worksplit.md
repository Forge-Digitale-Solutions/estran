# Estran — Work Split Contract

|                               |                                                                |
| ----------------------------- | -------------------------------------------------------------- |
| **Status**                    | Validated by DeepSeek V4.1 flash Free (Orca message `msg_182b6b63d034`) |
| **Date**                      | 2026-10-26                                                     |
| **Reference**                 | `ARCHITECTURE_PLAN.md`                                         |
| **First milestone**           | Jalon 1 = **M0 — Setup**                                       |
| **Lead / Integrator**         | DeepSeek V4.1 flash                                            |
| **Architect / Lead Reviewer** | DeepSeek V4.1 flash                                            |

## 1. Purpose

This contract prevents concurrent edits and defines the acceptance gate for every milestone. `ARCHITECTURE_PLAN.md` remains the technical source of truth. A code/plan divergence must be resolved explicitly: either DeepSeek updates the plan or the Lead fixes the code.

No milestone may be reported as validated when a blocking criterion is open or a required check was not actually run.

## 2. Roles and permanent ownership

| Owner | Exclusive write scope | Responsibilities |
|---|---|---|
| **DeepSeek V4.1 flash Free — Architect / Lead Reviewer** | `ARCHITECTURE_PLAN.md`, `review.md` | Architectural decisions, plan maintenance, milestone and slice reviews. Read access to the whole repository. No production, manifest, project, CI, or test edits unless the Lead explicitly delegates a precise scope. |
| **DeepSeek V4.1 flash Free — Lead / Integrator** | `worksplit.md`, `project.yml`, generated Xcode project files, root configuration, `scripts/`, `.github/`, `Estran/`, `EstranWidgets/`, `EstranTests/`, `EstranUITests/`, `Packages/EstranCore/Package.swift`, and all otherwise unassigned source/test files | Implementation planning, public contracts, project/target wiring, `DecisionEngine`, integration, worker verification, final checks, and blocker fixes. |
| **Delegated workers — Cursor, agy, or lower-cost OpenCode models** | Only the exhaustive file list in an active delegation | Short, isolated implementation or test tasks. No implicit directory-wide ownership and no integration into another worker's scope. |

Generated Xcode project files are Lead-owned even when produced by XcodeGen. Only the Lead edits `project.yml` or `Packages/EstranCore/Package.swift`; workers must request manifest or target-membership changes through the Lead.

### Permanent worker exclusions

Workers must never edit:

- `ARCHITECTURE_PLAN.md`;
- `worksplit.md`;
- `review.md`;
- `project.yml`, `.xcodeproj` files, or package manifests;
- CI, signing, entitlement, or secret-management files;
- any file outside their active delegation.

## 3. Edit locking and delegation protocol

1. There is exactly one active writer per file.
2. Before parallel work, the Lead defines public interfaces, fixtures, and the exact files owned by each worker.
3. Every delegation records the worker/model, task, exhaustive file list, and required checks in §7.
4. A worker returns the implemented files and check results; the Lead inspects the diff and reruns relevant checks before integration.
5. After integration, the Lead explicitly closes the delegation in the terminal and §7. Ownership then returns to the Lead.
6. No overlapping delegation is allowed until the previous one is closed. Any scope transfer is confirmed in the Orca terminal before editing.
7. No agent performs a commit, branch operation, rebase, reset, push, or other Git mutation without the user's explicit authorization.

## 4. Slice review gate

At the end of every functional slice, the Lead sends DeepSeek this request through `orca terminal send`:

> Merci de faire la revue de cette étape, écris ton rapport dans un fichier review.md et remonte uniquement les points bloquants

The Lead then runs `orca terminal wait`, reads `review.md`, fixes blocking findings, and requests another review when corrections require one.

DeepSeek owns and overwrites `review.md` for each requested review. Every report contains:

- milestone and slice identifier;
- exact reviewed scope (file list and, when available, commit range);
- checks inspected or executed, distinguishing **executed**, **pending**, and **not available**;
- `No blocking issues` when approved, or only blocking findings with `file:line`, impact, and required correction.

Non-blocking style remarks are excluded and left to formatters/linters. The Lead does not edit the review report.

A milestone is approved only after its final slice has passed this review and all platform-specific gates in §6 are green. If a required platform is unavailable, the gate remains explicitly pending; no successful build, test, archive, or CI run may be claimed without execution evidence.

## 5. Execution environments

- **Linux/local:** repository checks, scripts, lint/format checks when installed, and Swift build/tests for code supported by the installed toolchain. Apple-framework builds are not simulated.
- **macOS/Xcode:** XcodeGen generation, `xcodebuild` build/test/archive, simulator/UI checks, entitlement validation, and Apple-framework integration.
- **CI:** configured workflows and actual workflow results are reported separately. A workflow file's existence is not evidence that its jobs passed.

The initial host is Linux without Xcode. M0 must record the available toolchain and every command actually run. Missing local capabilities do not justify skipping a required final gate silently.

## 6. Milestones and acceptance criteria

### M0 — Setup (Jalon 1)

**Implementation owner:** Lead. Workers may receive isolated theme-token or configuration-test files, never project/manifest files.

Blocking checklist:

1. Repository structure matches `ARCHITECTURE_PLAN.md` §4: `Estran/`, `EstranWidgets/`, `Packages/EstranCore/`, `EstranTests/`, `EstranUITests/`, and `project.yml`.
2. Exactly two product targets exist: `Estran` and `EstranWidgets`; test bundles are separate test targets. The widget extension includes Live Activity/ActivityKit. Both product targets use the local `EstranCore` package.
3. XcodeGen generation resolves all source, resource, package, entitlement, and target-membership references.
4. App Group `group.com.forgedigitale.estran` and entitlements are present; no secret, API key, or private signing value is committed.
5. The M0 `EstranCore` skeleton contains only code supported by the declared Swift/Linux baseline; `swift build` and `swift test` pass with a real installed Swift 6 toolchain.
6. The SwiftData container baseline and initial theme tokens are present and wired without implementing future feature scope.
7. Format/lint configuration and CI workflows are present for Linux package checks and macOS `xcodebuild` build/test/archive.
8. Local checks are run where capabilities exist; the macOS build, tests, and archive pass before final M0 approval. Any unavailable run remains marked pending.
9. DeepSeek's final `review.md` reports `No blocking issues` for the complete M0 scope.

### M1 — Domain core

**Implementation owner:** Lead for integration and `Domain/DecisionEngine/`; workers may receive disjoint `Models/`, `Domain/Tides/`, fixture, and matching unit-test files.

Blocking checklist:

- all five activities and domain models conform to the agreed public contracts;
- pure rules are deterministic, bounded, `Sendable`, and covered by golden scenarios;
- next-good-window scanning, score thresholds, and blockers have edge-case tests;
- tide calculations pass reference fixtures and the D2 consistency rule (median `|Δt|` ≤ 12 min, p95 ≤ 35 min, **max ≤ `u_t` − 10 min**, `|bias|` ≤ 0.05 m, p95 `|Δh|` ≤ 0.40 m, max under-prediction ≤ `u_h` − 0.05 m at gauged stations **on the worst leave-one-year-out year**); **RMSE is a series property** (LOYO median ≤ 0.20 m, no year > 0.22 m, Z30); the coefficient is computed with the national Brest formula (`range / 6.10 × 100`), is **not displayed**, and stays `coefficientValidated = false` until a published sample meets ±1 for ≥ 90 %;
- confirmed spot/station data and REFMAR-derived harmonic constants are embedded—placeholder data cannot pass the final gate; the **v1 catalog is the 2 gauged spots** (D3 = Option A) and the fail-closed gate policy is tested over the full uncertainty interval, not at the envelope corners;
- the loader rejects an estimated spot, a correction on a gauged spot, an inactive envelope, a missing `validUntil`, and `official: true`;
- every station carries `validUntil` and the engine fails closed past it; the generated JSON loads into `TidalStation`/`TideEngine` through `TideModelLoaderTests` with no manual patching;
- package unit tests pass and DeepSeek approves the reviewed rule logic.

### M2 — Data

**Implementation owner:** Lead for `ConditionsProvider` and integration; workers may receive isolated DTOs, fixtures, and tests.

Blocking checklist:

- WeatherKit, Open-Meteo Marine, spots catalog, and cache implement the agreed protocols without duplicating domain decisions;
- recorded DTO/decoder tests, malformed-response tests, TTL tests, and cache round-trips pass;
- offline/stale-data behavior is explicit and tested; provider failures never produce a fabricated favorable decision;
- no runtime tide API or backend dependency is introduced;
- WeatherKit entitlement and Apple-framework integration pass on macOS; network-facing behavior respects the on-device constraint;
- DeepSeek approves the data pipeline and offline safety.

### M3 — UI

**Implementation owner:** Lead for stores, navigation, and integration; workers may receive isolated views/components and previews after their contracts are fixed.

Blocking checklist:

- Home, spot detail/tide chart, activity picker, and onboarding flows use the shared store and decision engine;
- **surfaces are iOS 27 glass**, not pre-26 materials: `glassEffect(_:in:)`, `GlassEffectContainer` where shapes merge, `.buttonStyle(.glass)` for controls; no `.ultraThinMaterial` in a shipped surface (early M3 review, point 1);
- **no stale cross-spot state**: a spot change clears conditions, forecast, decision and windows before the new data loads; every data-driven view is derived from `phase == .ready` (point 2);
- **no silent zero**: a missing tide event renders « — », never `0,0 m`; a missing measurement is never a neutral value (point 3);
- **unavailable ≠ no window**: when the activity is in `unavailableActivities`, the window card says « Créneaux indisponibles », never « Aucun créneau » (point 4);
- **44 × 44 pt minimum** on every tappable control at the default text size (point 5);
- **VoiceOver parity**: the answer card's label says everything the card displays, including the tide detail line (point 6);
- **the coefficient is absent from every screen in v1**; the reason line keeps the tide event only (point 7);
- **baignade is a risk level, never a verdict**: `SwimmingRiskLevel` (`faibles` / `modérés` / `forts` / `non estimés`) is computed from `spot.swimmingRange` (local predicted range) + tide phase, and replaces the giant Oui/Non on every surface (app card, map badge, widget, Live Activity, Siri); no « Oui », no green. The card order is **title → warning → conditions → level**, and the level is caption, never `metricValue`. `SwimmingAdvisory` adds the conditions line (« Vent 38 km/h · houle 1,5 m · eau 17 °C ») and the non-current blockers in words (« vent fort », « houle trop forte », « eau froide », « la nuit », « orage »); they never raise the current level. The coast-specific warning + « L'app estime les courants de marée… » are permanent and included in the VoiceOver element;
- the alerts tab reads the current notification authorization on appear; the scheduling itself is an explicit M4 dependency of the first TestFlight build (point 8);
- dataset-derived facts (source last update, model labels) are read from the dataset, never hard-coded (point 9);
- every preview loads the DEBUG demo forecast, so it never sits on « Chargement » (point 10);
- **the map is a 2-spot focus map**, not a browsing map: it opens centred on the selected spot, the camera animates between Arcachon-Eyrac and Pointe de Grave, and the floating Liquid Glass `SpotSwitcher` is the only place a spot is chosen in the app (map, widget setting and Siri `SpotEntity` read the same selection store);
- **no third spot, no empty pin, no greyed-out spot, no « bientôt »** anywhere in the UI; the product states two places plainly;
- confirmed Figma mockups are matched; missing mockups remain an explicit external dependency;
- all user-facing copy is French, short, and uses the agreed tutoiement;
- **Dynamic Type AX5 is a gate at M3, not at M6.** Every screen is built and verified at AX5 from its first commit: no fixed height on a text container, no `.lineLimit(1)` on a meaningful string (the compact Dynamic Island spot name is the one documented exception, `DESIGN_REFERENCE.md` §2.1), no `.dynamicTypeSize(...)` clamp without a written justification recorded in `DESIGN_REFERENCE.md` §2.1; horizontal pairs reflow to vertical stacks at accessibility sizes; widgets and Live Activity layouts are checked at AX5 as soon as they exist;
- **VoiceOver passes at M3**: the verdict is one element read as a sentence (« Oui, pêche à pied, marge suffisante »), every verdict carries text and an icon (colour is never the only signal), the tide chart exposes its next event as an accessibility value, and the `SpotSwitcher` announces the selected spot and what activating a chip does;
- contrast ≥ 4.5:1 on body text and non-color Oui/Non signals are present;
- previews and unit/UI tests pass on macOS; no placeholder flow is presented as complete;
- DeepSeek approves architecture and flow integration.

### M4 — Intelligence

**Implementation owner:** Lead for intent/store integration; workers may receive deterministic template tests or isolated intent fixtures.

Blocking checklist:

- `ReasonTextProviding` isolates Foundation Models from the deterministic template fallback;
- fallback text is deterministic, French, concise, and correct for every blocker/rationale fixture;
- unavailable Apple Intelligence never prevents a decision from being displayed;
- App Intents/App Shortcuts reuse the same engine and return consistent answers;
- local notification authorization, scheduling, rescheduling, and cancellation are tested;
- Siri/intent and notification behavior passes on the required Apple runtime; DeepSeek approves the slice.

### M5 — Glanceable

**Implementation owner:** Lead for App Group snapshots, background refresh, and extension integration; workers may receive isolated widget views and snapshot fixtures.

Blocking checklist:

- app and widget extension consume the same serialized `EstranCore` decision snapshot through the App Group;
- **widgets ship in all four v1 surfaces**: Home small / medium / large + Lock Screen; each renders the same `GoDecision` snapshot and the same 2-spot selection as the app;
- widgets do not perform network calls; timelines handle missing/stale snapshots honestly;
- Live Activity and Dynamic Island display the agreed states without duplicating decision logic;
- **swimming is fed, not left on the fallback**: `GoTimelineProvider` builds `GoEntry.swimmingAdvisory` from the shared snapshot, and the app starts the Live Activity with `ContentState.swimmingAdvisory`; the `.unknown` default must never be the production value (review v10, point 2);
- **the swimming level is per instant, not per day**: a strong-eligible day reads `forts` at mid-tide and `modérés` at slack. Widgets and the Live Activity refresh at the same cadence as the shared snapshot, not once a day, or a stale `forts` stays on the lock screen until the next slack (review v12, point 1);
- background refresh updates snapshots and scheduled surfaces without backend push;
- widget/extension builds and relevant simulator/device checks pass on macOS;
- DeepSeek approves the shared-data and lifecycle implementation.

### M6 — Polish and ship

**Implementation owner:** Lead; narrowly scoped accessibility, copy, and regression-test tasks may be delegated.

Blocking checklist:

- all previous milestone gates remain green;
- **accessibility re-audit on device, not first pass:** AX5 and VoiceOver were M3 gates and are re-verified here on real hardware, together with Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text and Differentiate Without Colour;
- no `.dynamicTypeSize(...)` clamp survives without a written justification in `DESIGN_REFERENCE.md` §2.1;
- French localization and `stop-slop-fr` copy pass are complete;
- regression, performance, and relevant UI tests pass;
- the app archives successfully with required signing and entitlements;
- TestFlight/release readiness is verified with real credentials and execution evidence; unavailable credentials leave this gate pending;
- DeepSeek's final `review.md` reports `No blocking issues`.

## 7. Delegation log

| ID | Worker / model | Task | Exclusive files | Required checks | Status |
|---|---|---|---|---|---|
| D0 | OpenCode MiniMax M3.1 Flash | Initial theme tokens | `Estran/Theme/OceanPalette.swift`, `Estran/Theme/OceanTypography.swift` | — | Closed — worker quota error before writing; Lead implemented the scope |
| D1a | OpenCode GPT-5.4 Mini | Harmonic tide engine and tests | `Domain/Tides/HarmonicPredictor.swift`, `Domain/Tides/TideEngine.swift`, `Tests/EstranCoreTests/TideFixtures.swift`, `Tests/EstranCoreTests/TideEngineTests.swift` | `swift build`, `swift test` | Closed — provider error “Insufficient account funds” before any write; no file created |
| D1b | OpenCode GLM-5.3 Flash Free | Harmonic tide engine and tests | Same four files as D1a | `swift build`, `swift test`, SwiftFormat lint | Closed — Lead verified, fixed force unwraps and the model epoch, 16 tide tests pass |
| D2 | OpenCode GLM-5.3 Flash Free (read-only web research) | Tide data sourcing report | `docs/data-sourcing/SHOM_DATA_SOURCING.md` (single file; no code, manifest, test or Git access) | Lead re-verified licence clauses, prices, formats, WFS station records, REFMAR licence and atlas prices against the primary PDFs/pages | Closed — v1 delivered (S1–S7 review), v2 by the Lead, then **v3 zero-budget rewrite** after Z1–Z6: REFMAR primary, Licence Ouverte 2.0 verified, harmonic spec, station QC, accuracy POC, coefficient defect. SHOM kept only as a labelled appendix. |
| D2b | OpenCode GLM-5.3 Flash Free | Extend `ConstituentSpeeds` with MN4, 2Q1, RHO1, M1 + validation test | `Packages/EstranCore/Sources/EstranCore/Models/TideStation.swift`, `Packages/EstranCore/Tests/EstranCoreTests/TidalStationValidationTests.swift` | `swift build`, `swift test`, SwiftFormat lint | Closed — Lead fixed the worker's non-compiling optional assertion with `XCTUnwrap`; **83 tests, 0 failures**; SwiftFormat **0/55**; build pass |

## 8. Validation record

| Milestone / slice | Local checks | Apple-platform checks | Review | Status |
|---|---|---|---|---|
| Contract | Lead self-check | Not applicable | `WORKSPLIT VALIDÉ` from the designated Architect session | Validated |
| M0 — Setup | `swift build` and `swift test` pass with Swift 6.0.3 (3 tests); SwiftFormat lint pass; plist/JSON/YAML parsed; static target/path/App Group checks pass; `xcodegen generate` pass with XcodeGen 2.46.0 built on Linux | Pending — no Xcode, Apple SDK, SwiftLint, or CI execution | `review.md`: **No blocking issues** (2026-10-26) | Code review passed — macOS/CI gates pending |
| M1 — Domain core | **M1 data layer closed (review v8, no blocker).** **164 package tests pass** (rules, golden scenarios, window scanning, solar daylight, tide helpers, tide engine, safety gates, station validation, constituent coverage, interval uncertainty gate, dataset loader, shipped dataset, labels, interval coverage, horizon, national coefficient, LOYO time and height bounds, swimming range); SwiftFormat lint **0/89 files**; `swift build` pass; `scripts/check-linux.sh` pass | Pending — no Apple SDK. **B5 data gate closed**; **Z20–Z30 closed**; **M1 data layer closed (review v8)**; horizon 2029 | `review.md` v8: Z29/Z30 closed, M1 data layer closed; dataset production recorded in §8.4 | Code review passed on real data — Apple gates pending |

### 8.1 M1 review remediation (B1–B4, B6)

| Finding | Correction | Regression evidence |
|---|---|---|
| B1 — windows and slots contained blocked samples | `WindowScanner` now takes an `isGood: (Conditions) -> Bool` predicate and infers the sampling step; `ActivityRule.nextGoodWindow` and `DecisionEngine.windows` pass the full `isGo` predicate; a slot is `go` only when every contained sample is unblocked; `decide` prefixes the current conditions and never advertises a window containing a blocked sample | `WindowScannerTests.testBlockedSampleBreaksTheRun`, `DecisionEngineTests.testBlockedSampleSplitsWindowsEvenWithAHighScore`, `testDecisionAtABlockedSampleDoesNotOfferAWindowStartingNow`, `testBlockedSamplesAloneProduceNoWindow` |
| B2 — missing safety-critical signals scored as neutral | Missing low-water event, sea-surface temperature or tide height now emits `.dataUnavailable` and scores 0 for that signal; a missing signal can never produce `Oui` | `GoldenScenarios` “without a low-water event”, “without a sea-surface temperature”, “without a tide curve”; `SafetyGatesTests.testMissingSafetyDataNeverProducesAGo` |
| B3 — rules contradicted the §7.1 Go conditions | Hard gates added for all five activities: pêche (coefficient ≥ 70, ≤ 2 h from low water, wind < 15), surf (wave 0.8–2.5 m, period 8–14 s, wind < 20, swell direction ≤ 90°, data present), bateau (wind < 20, swell < 1 m, visibility ≥ 0.5 km, water height ≥ draught), balade (wind < 30, 8–30 °C, rain < 60 %), baignade (water ≥ 18, air ≥ 20, wind < 20, swell < 0.8, daylight, no strong current) | `SafetyGatesTests` boundary cases for every activity; 10 new `GoldenScenarios` probes matching the review’s probe table |
| B4 — `TidalStation.validationError` accepted unusable data | Validation now rejects unresolvable time zones, non-finite `meanSeaLevel` / `meanSpringRange` / amplitude / phase / coordinates, out-of-range coordinates, empty or unknown constituents and duplicates | `TidalStationValidationTests` (9 cases, including `TideEngine.init` rejection) |
| B6 — spring-tide current was treated as safe when its phase was unknown | `SwimmingRule` now tri-states the current gate: below coefficient 100 it does not apply; inside the 0.4…0.6 phase band it emits `.strongCurrent`; at coefficient ≥ 100 with a missing or non-bracketing tide phase it emits `.dataUnavailable` and scores the current signal 0.2, so uncertainty cannot yield `Oui` | `SafetyGatesTests.testSwimmingSpringTideWithoutTideEventsIsBlocked`, `testSwimmingSpringTideWithNonBracketingEventsIsBlocked`, `testSwimmingSpringTideInTheStrongCurrentBandIsBlocked`, `testSwimmingNeapTideDoesNotRequireTheCurrentPhase` |

### 8.2 M1 v4 review remediation (Z7–Z13)

| Finding | Correction | Regression evidence |
|---|---|---|
| Z7 — the envelope was a p95 presented as a fail-closed bound | Envelope is now a **bound**: measured max `\|Δt\|` + stated allowance, p95 `\|Δh\|` + stated allowance; the report states that max `\|Δh\|` was not retained by the POC and makes it a required release metric (`maxHeightMeters`) | `SHOM_DATA_SOURCING.md` §6.1, §6.5; dataset contract §4.7 |
| Z8 — `lag 0 / amp 1.0` invented a correction | `correctionStatus` (`none`/`calibrated`/`estimated`) added; `none` is explicitly not an identity claim; the bound carries the risk until DeepSeek's lag/FES2022 derivation is validated | `TideModelLoaderTests.testUncalibratedIdentityCorrectionStaysDistinctFromACalibratedOne` |
| Z9 — `meanSpringRange` undefined, stale constituent gap | `2 · (M2 + S2)` defined and implemented (`TidalStation.derivedMeanSpringRange`); `nphma − npbma` forbidden; 25-symbol set documented as closed; generated JSON now loads through `TideModel` | `testDerivedMeanSpringRangeUsesM2AndS2`, `testStationWithoutM2OrS2HasNoDerivedMeanSpringRange`, `TideModelLoaderTests.testGeneratedJSONLoadsIntoAStationAndEngine` |
| Z10 — no validity horizon, §4.1/§4.3 contradiction | `validUntil` required in the dataset and `TidalStation`; `TideEngine.state` throws `outsideValidity` past it; `nodalCorrections: true` rejected; single `f = 1, u = 0` convention documented | `TideModelLoaderTests.testEngineFailsClosedPastTheValidityHorizon`, `testDatasetWithoutHorizonIsRejected`; `TidalStationValidationTests.testStationRejectsNodalCorrectionsTheEngineCannotApply` |
| Z11 — « mesure locale » claimed a measurement | `Spot.modelLabel`: gauged → « modèle local — station 15/190 », estimated → « estimation — modèle local »; forbidden strings tested | `TideModelLoaderTests.testSpotLabelsNeverClaimALocalMeasurementOrOfficialData` |
| Z12 — Cap Ferret lagoon, Pyla identity | Cap Ferret → `estimatedOpenCoast` (inlet/ocean); Pyla → `estimatedOpenCoast` (south pass); Andernos/Arès/Gujan → `estimatedLagoon`; per-spot envelope by class | `SHOM_DATA_SOURCING.md` §7.1; `DESIGN_REFERENCE.md` §4 |
| Z13 — gate sampled only the corners | Full-interval gate: `minimumHeight` (curve + exact events), `maximumMinutesFromNearestEvent`, `phaseIntersects`, daylight at both endpoints; `.insufficientMargin` (« Marge insuffisante ») when nominal passes but the interval does not; `.dataUnavailable` when the interval is not covered | `UncertaintyGateTests` (5 tests), `SafetyGatesTests` unchanged and green |

**v4 verification run (2026-10-27, Linux host):** `scripts/check-linux.sh` exit 0 — `swift build` pass, `swift test` **100 tests / 0 failures**; SwiftFormat lint **0/58 files**; both `Info.plist` parsed with `plistlib`; `project.yml` structurally parsed. Apple-platform gates remain **pending** (no Xcode/Apple SDK).

### 8.3 M1 v5 review remediation (Z14–Z19)

| Finding | Correction | Regression evidence |
|---|---|---|
| Z14 → Z21/Z27 — `u_h` was a p95, then a two-sided max | **Closed.** `u_h` is one-sided and sized on leave-one-year-out: **0.70 m** (190) / **0.60 m** (15), from the worst year (2022) + 0.05; the dataset publishes `maxUnderPredictionMeters`, `minOverPredictionMeters` and the LOYO table; `maxAbsoluteErrorMeters` is information only. The generator aborts if the declared bound does not cover the measurement | `ShippedDatasetTests.testShippedAccuracyPublishesTheOneSidedHeightBound`; `SHOM_DATA_SOURCING.md` §6.5 |
| Z15 — the gate never checked interval coverage (fail-open at midnight) | `TideState.coversInterval` rejects an interval outside `safetyCurve`; `TideEngine` builds `safetyCurve` over the local day **± 2 h**; `minimumHeight`, `maximumHeight`, `maximumMinutesFromNearestEvent` and `phaseIntersects` return `nil` when uncovered → `.dataUnavailable` | `HorizonAndCoverageTests.testEngineStateCoversTheEnvelopeAroundMidnight` (23:55 / 00:05), `testIntervalOutsideTheSafetyCurveIsRejected` |
| Z16 — `validUntil` checked at `t`, gate reads to `t + u_t` | `TideState.validUntil` is copied from the station; `RuleSignals.isBeyondValidityHorizon` compares `at + u_t` and appends `.dataUnavailable` in all five rules | `HorizonAndCoverageTests.testHorizonIsCheckedAtTheEndOfTheUncertaintyInterval` |
| Z17 — an inactive envelope passed the dataset contract | `TideModel.validationError` rejects an inactive envelope, a non-gauged spot and a non-`none` `correctionStatus` | `TideModelLoaderTests.testInactiveEnvelopeIsRejected`, `testEstimatedSpotIsRejectedByTheV1Contract`, `testCorrectionOnAGaugedSpotIsRejected` |
| Z18 → Z23 → v11 — the spring-current gate used the local coefficient, then the national one | **Closed by product decision:** the swimming level now uses the **local predicted range** (`spot.swimmingRange`: `lowBelow` / `strongAt`) and the tide phase, calibrated in the generator on the same number of days as `coef ≥ 100` at Brest. `strong` ≥ `strongAt` mid-tide, `moderate` inside the ±0.30 m grey band, `low` below. `coefficientValidated` no longer conditions swimming; the coefficient remains hidden and post-v1. | `SwimmingRangeTests`, `SafetyGatesTests.testSwimmingRangeInsideTheGreyBandBlocks`, `ShippedDatasetTests.testShippedSwimmingRangeIsCalibrated` |
| Z19 → Z22/Z29 — Arcachon low-water error exceeds the declared bound | **Closed with D2 as a consistency rule, now LOYO.** Station 15 → `u_t = 75 min` (LOYO max 64.76 in 2023 + 10); station 190 → `u_t = 70 min` (LOYO 53.33 + 10 = 63.33; SHOM 69.8 stricter). Pêche à pied stays active at Arcachon; its `Oui` window shrinks to ≈ 50 min around low water, and to ≈ 45 min at Pointe de Grave | `SHOM_DATA_SOURCING.md` §6.5, §7.3 |

**v5 verification run (2026-10-27, Linux host):** `swift build` pass; `swift test` **108 tests / 0 failures**; SwiftFormat lint **0/58 files**. Apple-platform gates remain **pending** (no Xcode/Apple SDK).

**v1 product consequences to keep explicit:** only 2 spots; the 12 estimated spots are post-v1; baignade is a **risk level** (`SwimmingRiskLevel`) computed from the local predicted range, never a `Oui`; the national coefficient is not displayed and remains post-v1; the tide horizon is 2029 and the dataset is regenerated once a year (`BUILD.md`). Pointe de Grave's pêche à pied window is ≈ 45 min around low water after the LOYO time bound.

### 8.4 Dataset production (`tide-model-2026.1`)

**Built 2026-10-27, Linux host, zero budget, Licence Ouverte 2.0.**

| Item | Result |
|---|---|
| Generator | `scripts/tides/refresh` (stdlib-only Python 3): verified REFMAR access path, ≤ 31-day chunking with an explicit truncation guard, QC, 25-constituent least squares, dataset + Markdown report |
| Access | `GET /maregraphie/observation/json/{station}?sources={1\|3\|4}&dtStart=…&dtEnd=…`; source 4 for the fit, source 3 for the extrema cross-check, source 1 unused for v1 |
| Stations | **190** `ARCACHON_EYRAC` (bassinReference), **15** `PORT-BLOC` (oceanReference), **3** `BREST` (coefficientReference) — 25 constituents each |
| Fit windows | 190: 2022–2024 + 2026-H1; 15: 2022–2023 + 2026-H1 (2024 excluded); 3: 2022–2024 + 2026-H1. **2025 held out in every case** |
| Horizon | `validUntil` **2029-06-30** (190, 3) and **2029-06-15** (15); `TideEngine` throws `outsideValidity` past it. The horizon bounds astronomical decay (nodal drift), not weather dispersion; annual regeneration is a ritual (`BUILD.md`) |
| Spots | 2 gauged only: `pointe-de-grave` (15, `u_t` **75 min**, `u_h` **0.60 m**) and `arcachon-eyrac` (190, `u_t` 70 min, `u_h` **0.70 m**); LOYO time and height bounds (Z21/Z27/Z29); `basis` generated (Z24) |
| Accuracy (held-out 2025, complete year) | 190 n=8760 RMSE 0.1605 / bias −0.0062 / p95 0.3146 / **max under-prediction 0.5032** / min over −0.9436; 15 n=8753 0.1467 / −0.0144 / 0.2983 / **0.3926** / −0.7802; 3 n=8760 0.1475 / −0.0147 / 0.2907 / **0.4776** / −0.7505 |
| Extrema (low / high, med / p95 / max min) | 190: 11.62/32.17/**50.00** and 10.00/31.67/52.14; 15: 7.83/25.00/45.08 and 7.69/25.62/44.17; 3: 6.99/17.86/30.50 and 7.29/17.32/37.68 |
| Targets | D2 consistency rule (Z22): bias, p95 and `max ≤ u_t − 10` met at all three; the old absolute 45-min target is withdrawn. **LOYO (Z27/Z29)**: worst under-prediction 0.6059 (190, 2022) / 0.5113 (15, 2022); worst `|Δt|` 53.33 (190, 2024) / 64.76 (15, 2023). **RMSE series (Z30)**: median 0.180 / 0.165 / 0.162, max 0.209 / 0.208 / 0.189 — passes |
| QC | Z20: full 31-day windows with exclusive `dtEnd`; 2025 sample 8760 (190/3) and 8753 (15); documented outages only (190 28 h, 15 16 short outages, 3 489 h); a gap > 1.5 h is fatal unless allowlisted; datum step ≤ 0.070 m |
| Sanity | Fitted MSL 2.537 / 3.375 / 4.262 m vs SHOM `niveau_moyen` 2.48 / 3.29 / 4.14; `meanSpringRange = 2·(M2+S2)` 3.44 / 3.92 / 5.48 m |
| Regression gate | `ShippedDatasetTests` (9 tests) loads the bundled JSON, checks schema 6, the v1 contract, the per-station envelopes, the unvalidated national coefficient, the swimming fail-closed state, the one-sided bound, the horizon and three REFMAR observations at 190 |
| Reproduce | `scripts/tides/refresh` (cache under `scripts/tides/.cache/`, must be git-ignored before the first commit) |

**Open after production:** the Brest coefficient validation (for the future displayed coefficient, not the swimming level), and the **annual regeneration ritual** (`BUILD.md`) before the 2029 horizon (Z28).

**v6 verification run (2026-10-27, Linux host):** `scripts/check-linux.sh` exit 0 — `swift build` pass, `swift test` **164 tests / 0 failures**; SwiftFormat lint **0/89 files**. Apple-platform gates remain **pending** (no Xcode/Apple SDK).

## 9. Open external dependencies

| Dependency | Needed for | State |
|---|---|---|
| REFMAR-derived harmonic constants (Licence Ouverte 2.0) | M1 final gate: real tide predictions, coefficient, accuracy | **Built (2026-10-27).** `tide-model-2026.1.json` ships in `EstranCore/Resources`, `schemaVersion: 6`, 3 stations (190, 15, 3) × 25 constituents, 2 gauged spots. `scripts/tides/refresh` reproduces it (verified access path, 31-day chunking with a truncation guard, QC, fit, dataset + report). Licence Ouverte 2.0, no paid product, no runtime API. |
| D3 — coverage | M1 final gate: v1 product scope | **Revised — Option A** (Anthony, 2026-10-27): v1 ships **2 spots only**, Pointe de Grave / Le Verdon (15) and Arcachon-Eyrac (190). The 12 estimated spots leave the v1 catalog — no « bientôt », no display. Option B is dropped; the 12 spots are a post-v1 roadmap. Recorded in `ARCHITECTURE_PLAN.md` §8.1/§18 and the v5 sourcing report §7.2. |
| Confirmed spot catalog and station references | M1 final gate: real coordinates, `coastOrientationDegrees`, `minimumWaterHeight`, station mapping | **v1 = 2 gauged spots.** Pointe de Grave (15, QC 297) and Arcachon-Eyrac (190). Coordinates still need IGN/OSM verification. `correctionStatus: none` and a per-spot envelope are required by the loader; the lag interpolation / FES2022 work on the 12 estimated spots is **stopped** and moved to the post-v1 roadmap. |
| Independent accuracy references | M1 final gate: accuracy evidence | **Measured on the shipped dataset** (held-out 2025 complete year, `docs/data-sourcing/accuracy-2026.1.md`): 190 n=8760 RMSE **0.1605 m** / bias −0.0062 / p95 0.3146 / **max under-prediction 0.5032** / min over −0.9436, extrema low 11.62/32.17/**50.00 min**, high 10.00/31.67/52.14; 15 n=8753 0.1467 / −0.0144 / 0.2983 / **0.3926** / −0.7802, low 7.83/25.00/45.08, high 7.69/25.62/44.17; 3 n=8760 0.1475 / −0.0147 / 0.2907 / 0.4776 / −0.7505. **LOYO (Z27/Z29)** sizes `u_h`: 190 0.6059 (2022) → 0.70; 15 0.5113 (2022) → 0.60; and `u_t`: 190 53.33 (2024) → 70; 15 64.76 (2023) → 75. **RMSE series (Z30)**: median 0.180 / 0.165 / 0.162, max 0.209 / 0.208 / 0.189. The 2026-H1 stress test is an anomalous-pressure year (Z26), not a horizon measurement. |
| Coefficient de marée formula | M1 final gate | **Implemented, not validated (Z23).** The engine computes `C = range_Brest / 6.10 × 100` (clamped 20…120) from station 3 and reports `.nationalBrest` with `coefficientValidated = false`. The pêche à pied gate is on the national scale at **72**; the coefficient is **not displayed**. Baignade no longer depends on it: it uses the local `swimmingRange` (v11). |
| Constituent table and nodal corrections | M1 final gate | **Constituent table closed; nodal deferred with a hard horizon.** `ConstituentSpeeds` has **25 symbols**, including **MN4, 2Q1, RHO1, M1**; `testCompoundAndLongPeriodConstituentsAreSupported` passes (164 tests total). The engine has no `f`/`u`: the dataset must declare `nodalCorrections: false` and a required `validUntil` (fit end + 3 years for every station, Z28: 2029); `TideEngine` throws `outsideValidity` past it. `nodalCorrections: true` is rejected at load. |
| **`u_h` after Z21/Z27** | **Release gate: water-level bound** | **Closed.** `u_h = LOYO max(pred − obs) + 0.05 = 0.70 m` (190) / `0.60 m` (15); worst years 0.6059 (190, 2022) and 0.5113 (15, 2022). Product cost measured: tide-only boating availability 80.8 % of hours at 190 (84.5 % at 0.60). |
| Dataset loader and interval gate | M1 final gate: JSON → `TidalStation` → `TideEngine`, fail-closed decisions | **Implemented and tested (v6).** `ShippedDatasetTests` loads the real bundled dataset through `ShippedTideModel`, checks schema 6, the contract, the per-station envelopes, the unvalidated national coefficient, the swimming fail-closed state, the one-sided bound, the horizon and three REFMAR observations at 190; it fails if the shipped file is missing or expired. `TideModelLoaderTests` loads a generated-schema JSON, builds the engine, checks a known date and the `validUntil` failure; it rejects an inactive envelope, a non-gauged spot and a non-`none` correction. `UncertaintyGateTests` covers a low water inside the envelope, a low water pushed out of the pêche gate, a phase-band crossing and the no-envelope nominal path. `HorizonAndCoverageTests` covers midnight coverage (23:55 / 00:05), an uncovered interval, the horizon at `t + u_t`, and the local-proxy coefficient. |
| National coefficient (Brest, station 3) | Baignade current gate, displayed coefficient | **Model fitted, validation missing (Z23).** Station 3 ships (`role: coefficientReference`, RMSE 0.1475 m); the engine computes `C = range_Brest / 6.10 × 100`. It is **not validated** against a published Annuaire sample (bias +1.75, 37 % within ±1), so `coefficient.validated = false`, the coefficient is not displayed, and `SwimmingRule` stays `.dataUnavailable`. |
| Pass-current validation source | M1 safety gate (coefficient ≥ 100, phase 0.4–0.6) | **Unavailable.** The free Gascogne 2D atlas is 2 km / 30 min / coefficients 45–95 only, so it cannot resolve the inlet; the 565 atlas is PDF-only. The gate stays a documented conservative heuristic unless an in-situ campaign or a bespoke SHOM study is funded. The national coefficient path is implemented but unvalidated, so baignade remains fail-closed. |
| Tide horizon refresh | Release validity: `validUntil` 2029 | **Annual ritual (Z28).** Run `scripts/tides/refresh` once a year (`BUILD.md`). The horizon bounds astronomical decay, not weather; a skipped year does not brick the app but ages the model. |
| Alert scheduling (M2/M4) | Alerts tab → first TestFlight build | **Open dependency.** The preference and the authorization status ship in M3; scheduling one hour before a good window needs the live conditions (M2) and is wired with the notification scheduler (M4). The tab must not reach TestFlight before scheduling exists, or it is hidden. |
| Marine SST in the Bassin (M2) | Swimming level once the gate opens | **Risk to test when the marine source lands.** Open-Meteo Marine may not return a sea-surface temperature inside the lagoon. `SwimmingRule` sets `.dataUnavailable` when SST is nil, which would make the level `unknown` permanently, whatever the tide. Test one point at Arcachon-Eyrac and one at Pointe de Grave. If SST is missing in the Bassin, decouple: the current level uses tide + coefficient; temperature becomes a separate line (« eau : indisponible »). |
| Swimming range calibration (v11) | Baignade level, per spot | **Built.** `spots[].swimmingRange` from the local predicted range: **190** `lowBelow 3.58` / `strongAt 4.18`; **15** `4.03` / `4.63`. `T` is the range reached on the 37 days where the national coefficient reaches 100 in 2025; the band is `T ± 0.30 m`. `SwimmingRule` uses range + phase; no `low` inside the band; a missing range is `Courants non estimés`. |
| macOS/Xcode runner | M0/M1/M3 Apple-platform gates | **Pending.** No Xcode or Apple SDK on the current Linux host. `glassEffect(_:in:)`, `GlassEffectContainer(spacing:content:)`, `Glass.regular` / `.tint(_:)` and `.buttonStyle(.glass)` were checked against the iOS 26 SDK documentation, but no compiler has seen them. The M3 build checkpoint is the first Mac task. |
