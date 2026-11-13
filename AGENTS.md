# AGENTS.md

Operating manual for an agent (or a human) picking this repository up. Read it
before touching anything; the rest of the truth is in the files listed at the end.

## The product

Estran answers **« C'est un bon moment pour sortir ? »** for five coastal
activities on two spots of the Bassin d'Arcachon and the Médoc. French UI,
on-device, free, no account, no backend.

## Non-negotiable invariants

Violating one of these is a regression, even if the code is cleaner afterwards.

1. **No `Oui` for swimming, on any surface** — app, widget, Live Activity, Siri,
   Shortcuts. It is a risk level plus a year-round warning about baïnes and
   currents (`ARCHITECTURE_PLAN.md` §7.3).
2. **Never claim officiality.** « modèle local », never « SHOM », never
   « données officielles », never « mesure locale ».
3. **Never invent a value.** A missing measurement renders « — » or « Données
   indisponibles », never `0`, never a neutral default.
4. **Fail closed.** A missing safety input is a blocker, not a neutral score.
   « Unavailable » is a visible state, never a silent `Non`.
5. **Bounds are leave-one-year-out** (`u_t`, `u_h`): sized on the worst year of
   the record, not on one test year.
6. **The national Brest coefficient drives no safety decision.** It is computed,
   unvalidated, unshown. Swimming gates on the local predicted range.
7. **No paid data source, no runtime tide API.** The tide is embedded constants
   derived from open REFMAR observations. Weather is WeatherKit + Open-Meteo
   Marine.
8. **Two spots.** A third spot needs a tide gauge and a validated model, not
   coordinates and hope.

## Where the truth is

| Question | File |
|---|---|
| How is it built, and why? | `ARCHITECTURE_PLAN.md` |
| What should the screen look like? | `DESIGN_REFERENCE.md` |
| How do I build, sign, ship? | `BUILD.md` |
| What is the current milestone and its gate? | `worksplit.md` |
| Why is this code like this? | `review.md` (history of blocking findings) |
| How accurate is the tide model? | `docs/data-sourcing/accuracy-2026.1.md` |
| Where does the data come from, and under what licence? | `docs/data-sourcing/SHOM_DATA_SOURCING.md` |

## Commands

```sh
./scripts/check-linux.sh        # EstranCore build + tests (no Apple SDK needed)
./scripts/check-macos.sh        # xcodegen, xcodebuild build/test, lint (macOS only)
./scripts/check-macos.sh --archive
python3 scripts/tides/refresh   # regenerate the tide dataset (free, cached)
```

## Current state — 2026-11-12

| Milestone | State |
|---|---|
| M0 Setup | done — rebuilt on the new Mac (Xcode 27.2, iOS 27.2 sim); DerivedData lives in `build/` |
| M1 Domain + tide dataset | done — schema 6, 172 package tests |
| M2 Weather (WeatherKit + Open-Meteo Marine) | **live sources operational** — WeatherKit capability still to enable in the portal; lagoon sea decision open |
| M3 UI | **iOS 27 visual pass shipped** — living `OceanBackdrop`, interactive morphing Liquid Glass, zoom transition, tide scrub, concentric corners; settings pass (IC/RT/RM) done, map-card contrast B1/B2 fixed (`docs/accessibility/settings-pass-2026-11-11.md`); **device VoiceOver open** |
| M4 Foundation Models / Siri / notifications | **in progress** — `@Generable` reason with guardrails (verb + length checks, engine fallback), prewarm; Spotlight entities, App Shortcuts, Siri snippet; local notifications scheduled |
| M5 Widgets / Live Activity | **built** — small/medium/large + Lock Screen families, real swimming level fed; Live Activity with no go case for swimming, rendered at 370/393 pt; on-device check of widgets and Live Activity open |

iOS 27 SDK opportunities and what is already used: `docs/design/ios27-opportunities.md`.

**iPhone Duo (2026-11-13).** `UIRequiresFullScreen` is gone and all four
orientations are declared, so the app fills the unfolded display instead of the
letterboxed phone column. Home, Spots and the spot detail switch to two columns
from 700 pt of window width (`Estran/App/OceanLayout.swift`); the folded Duo and
every classic iPhone in portrait keep the phone layout, and accessibility sizes
always keep one column. Rationale, SDK citations and the verification gap are in
`docs/design/iphone-duo-2026-11-13.md` — the wide layouts still need a real Duo
pass, since the iOS 27.2 runtime crashes PosterBoard on this Mac.

**Next action: close M3, then M2.** `check-macos.sh` is green (build, tests,
lint, archive), the app runs in the simulator, and the three mockup screens that
exist are matched (`docs/design/figma-match-2026-10-28.md`). What still blocks
M3:

1. **Real-device VoiceOver** — the source audits are done
   (`docs/accessibility/`), the device pass is not.
2. **Increase Contrast, Reduce Motion, Reduce Transparency** on the glass
   surfaces, and the `SpotsView` glass measured over map tiles.
3. ~~The `Favori` heart~~ — **decided 2026-11-02**: dropped in v1, the model
   stays in the schema unused (`DESIGN_REFERENCE.md` §3.2).

Frame 04 (widgets, Live Activity) cannot match before M5. Then **M2**, which is
what makes the water temperature real.

M2 state (2026-10-28): the Open-Meteo Marine source, cache, per-spot policy and
tests are in; the WeatherKit service is written but the App ID capability is not
enabled on this Mac, so the live provider fail-closes on the weather. Two
decisions are open before the lagoon can answer: model a **missing sea** in the
domain (optional wave fields), or drop wave-dependent activities inside the
Bassin.

First-build evidence (2026-10-28): `xcodebuild` build/test and `--archive`
pass, 165 package tests pass, SwiftLint `0`, SwiftFormat `0/90`, app launched
on iPhone 18 Pro (iOS 27). The three accessibility audits (AX5, contrast,
VoiceOver) and their remediation are recorded in `docs/accessibility/` and
`worksplit.md` §8.6.

## Rules of engagement

- **Docs in English, UI copy in French.** Short sentences, tutoiement, no
  AI-isms. A local reads the UI; an agent reads the docs.
- **`dev` is the working branch, `main` is production.** Commit to `dev` when
  the owner asks; `main` only for a publishable state.
- **Do not silence a compile error** by removing an accessibility modifier, a
  `fixedSize` or an `@ScaledMetric`. Those are release gates.
- **Do not overwrite `BUILD.md`, `README.md` or `worksplit.md` wholesale.** They
  carry checklists other people depend on; edit the section.
- **A blocking finding in `review.md` is not a suggestion.** Do not ship around
  it.
- **Never edit the tide dataset or the accuracy report by hand.** Regenerate
  them; `BUILD.md` §7 is the ritual.

## Traps

- **REFMAR's 31-day limit is silent** and `dtEnd` is inclusive of the closing
  midnight: a naive chunking loses 23 h per window. The guard asserts the row
  count, not just the last timestamp.
- **`Estran.xcodeproj` is generated.** Run `xcodegen generate` after any
  `project.yml` change; never edit the project file by hand.
- **The tide cache is ~77 MB** and git-ignored. Never commit it.
- **`glassEffect` and `ControlWidget` are unverified** until the macOS build
  confirms their signatures.
