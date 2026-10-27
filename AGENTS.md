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

## Current state — 2026-10-27

| Milestone | State |
|---|---|
| M0 Setup | done |
| M1 Domain + tide dataset | done — schema 6, 164 tests |
| M2 Weather (WeatherKit + Open-Meteo Marine) | **not started** |
| M3 UI | written, **never compiled on macOS** |
| M4 Foundation Models / Siri / notifications | not started |
| M5 Widgets / Live Activity | views written, data path not wired |

**Next action: the first macOS build.** `glassEffect`, the swimming views and
the widget branches have never seen an Apple compiler. Everything else is
verified on Linux.

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
