# Tide Data Sourcing — Estran (iOS)

**Version:** 6.0 (dataset schema 6) · **Date:** 2026-10-27
**Governing constraint:** **0 € — no purchase, no subscription, no royalty, no paid licence.**
**Scope:** tide data for **embedded, offline** predictions in the Estran iOS app. **v1 covers two gauged spots only** — Pointe de Grave / Le Verdon (station 15) and Arcachon-Eyrac (station 190). The 12 other spots are a post-v1 roadmap (§7.1b). No runtime tide API: data acquired at build time, constants embedded in `EstranCore`, annual re-analysis.

**Evidence discipline:** every substantive statement is labelled **Fact** (directly sourced), **Inference** (reasoning from sources), **Measured** (executed on the date stated, method stated) or **Open question**. Anything not confirmed is written **not verified**. No tide *values* from a paid product are reproduced — identifiers, metadata, formats, licence clauses and derived statistics only.

> **What changed in v6.** The M1 review (Z20–Z30) is closed. `tide-model-2026.1.json` is regenerated as **schema 6**.
>
> - **Z20 — the chunker no longer loses 23 h per window.** Each request is a full 31-day span with an exclusive `dtEnd`; the 2025 held-out sample is **8 760** hours at 190/3 (8 753 at 15, two allowlisted outages). A gap > 1.5 h aborts the run unless dated and justified.
> - **Z21/Z27 — `u_h` is one-sided and sized on the series.** `u_h = 0.70 m` (190) / `0.60 m` (15), from the leave-one-year-out maximum under-prediction + 0.05 m, not `max |Δh|` and not a single neutral year. `maxUnderPredictionMeters` / `minOverPredictionMeters` are published.
> - **Z22/Z29 — D2 is a consistency rule.** `u_t(15) = 75 min` (LOYO max 64.76 in 2023 + 10); `u_t(190) = 70 min` (LOYO 63.33; SHOM 69.8 stricter). The generator aborts if an envelope does not cover the measurement.
> - **Z23 — the coefficient is national, unvalidated, and hidden.** `C = range_Brest / 6.10 × 100`; the pêche à pied gate moves to 72; the coefficient is not displayed in v1. Baignade uses the local predicted range (`swimmingRange`), not the coefficient (v11).
> - **Z24 — `basis` strings are generated** from the measured values in the same run.
> - **Z26/Z28 — the horizon is astronomical, not weather.** The 2026-H1 stress test is an anomalous-pressure year (January 2026 1007.9 hPa vs 1027.6 hPa in 2022), not model drift. `validUntil` is **2029** for all stations; annual regeneration is a maintenance ritual (`BUILD.md`).
> - **Z29/Z30 — time and RMSE get the series treatment.** `u_t` is sized on the worst leave-one-year-out `|Δt|` (190 53.33 → 70; 15 64.76 → 75). RMSE is a series property: LOYO median ≤ 0.20 m, no year > 0.22 m.
>
> **What changed from v5.** v5 answered the v4 review (Z14–Z19) and recorded Anthony's revised product decision:
>
> - **D3 revised to Option A.** v1 ships **2 gauged spots only**. The 12 estimated spots leave the v1 catalog and become a post-v1 roadmap; the lag/FES2022 work is stopped for v1. The loader now **rejects** a non-gauged spot, a correction on a gauged spot, and an inactive envelope (Z17).
> - **Z15 — interval coverage is enforced.** `coversInterval` rejects an interval outside the samples, and the engine builds a safety curve over the local day ± 2 h.
> - **Z16 — the horizon is checked at `t + u_t`.** The last envelope before `validUntil` is `.dataUnavailable`.
> - **Z18 — the spring-current gate fails closed.** `TideState.coefficientSource` distinguishes the national Brest coefficient from the local proxy.
> - **Z19 — per-station time bounds.** Station 190 → **70 min**, covering the SHOM 2025 low-water max of 57.8 min.

---

## 0. Decision summary

### 0.1 The only route under 0 €

```
REFMAR observations (free, Licence Ouverte 2.0)
        ↓  build-time download
least-squares harmonic analysis (our own computation)
        ↓  embedded JSON
EstranCore / widgets / Live Activity (no network)
```

The derived constants are **our own dataset**. They are **not** a SHOM prediction and must never be presented as official. The UI says **« estimation »** / **« modèle local »**.

### 0.2 Decisions

| # | Decision | Owner | State |
|---|---|---|---|
| **D1** | Data route | Lead + Architect | **Settled:** REFMAR zero-budget route. No paid product. |
| **D2** | Accuracy target | Architect | **Consistency rule (Z22).** median `\|Δt\|` ≤ 12 min, p95 ≤ 35 min, **max ≤ `u_t` − 10 min**; RMSE ≤ 0.20 m, `\|bias\|` ≤ 0.05 m, p95 `\|Δh\|` ≤ 0.40 m, max under-prediction ≤ `u_h` − 0.05 m. The old absolute 45-min target is withdrawn. |
| **D3** | v1 coverage | **Anthony** | **Revised — Option A** (2026-10-27): v1 ships **2 gauged spots only** (Pointe de Grave / Le Verdon, Arcachon-Eyrac). The 12 estimated spots are a post-v1 roadmap. See §7.1, §7.1b, §7.2. |
| **D4** | Coefficient de marée | Lead + Architect | **Implemented, not validated (Z23).** The engine computes `C = range_Brest / 6.10 × 100` from station 3. The model is fitted but not validated (bias +1.75, 37 % within ±1), so `coefficient.validated = false`; the coefficient is not displayed, the pêche à pied gate is 72, and baignade stays `.dataUnavailable` (§6.5). |
| **D5** | Licence and attribution | Lead | **Settled:** Licence Ouverte 2.0, attribution string in §1.4. |
| **D6** | Envelope basis | Architect | **Closed (Z21/Z22/Z27):** `u_t` and `u_h` are measured per station and **generated** into `uncertainty.basis`; the generator aborts if a declared envelope does not cover the measurement. `u_h = 0.70 m` (190) / `0.60 m` (15) is the one-sided bound `LOYO max(pred − obs) + 0.05`. Derivation in §6.5; gate in §7.3. |

### 0.3 B5 status

**Closed (2026-10-27):**

- `tide-model-2026.1.json` is committed for stations **190**, **15** and **3** (Brest), `schemaVersion: 6`;
- `scripts/tides/refresh` reproduces it end to end (download → QC → 25-constituent fit → dataset + report), with a cache and a truncation guard;
- the held-out 2025 accuracy report is **in the dataset** (`stations[].accuracy`), including **`maxUnderPredictionMeters`**, **`minOverPredictionMeters`** and the forward test;
- the dataset loads through `ShippedTideModel` / `TideModel.load` and passes `validationError`, proven by `ShippedDatasetTests`.

**Still open:**

- the Brest coefficient **validation** against a published Annuaire sample (the model is fitted, `coefficient.validated = false`, and the coefficient is not displayed; baignade no longer depends on it);
- the **annual regeneration ritual**: `validUntil` is 2029 for all stations; run `scripts/tides/refresh` once a year (`BUILD.md`). A skipped year does not brick the app, but the dataset should not age past the horizon;
- the macOS/Xcode gates (separate pending item).

No data has been purchased, no account created, no SHOM contact made, and no key is committed.

---

## 1. Licence — REFMAR under Licence Ouverte 2.0

### 1.1 Verified licence

**Fact** — the two REFMAR datasets published by Shom on data.gouv.fr are licensed **`lov2`** (Licence Ouverte 2.0 / Etalab):

| Dataset | Publisher | Licence | Last update |
|---|---|---|---|
| [REFMAR — Marégraphes RONIM](https://www.data.gouv.fr/datasets/reseaux-de-reference-des-observations-maregraphiques-refmar-maregraphes-ronim) | Shom | **lov2** | 2026-02-24 |
| [REFMAR — Marégraphes partenaires](https://www.data.gouv.fr/datasets/reseaux-de-reference-des-observations-maregraphiques-refmar-maregraphes-partenaires) | Shom | **lov2** | 2026-02-25 |

The RONIM dataset covers the Shom-operated network; the partner dataset covers the other REFMAR producers. `ARCACHON_EYRAC` (190), `PORT-BLOC` (15) and `BREST` (3) are RONIM; `PORT_BLOC_GPM` (297) is REFMAR. Both datasets are under the same licence, so the distinction does not change the rights.

**Scope of this verification:** the licence basis is the data.gouv.fr publication of the REFMAR products. The `services.data.shom.fr` API does not display a separate licence on its documentation page; if Shom publishes API-specific terms, they must be checked before release. The data served by the API is the same REFMAR product, so the data.gouv licence is the operative one (**Inference**, to confirm in the release checklist).

**Fact** — the Licence Ouverte 2.0 text ([etalab/licence-ouverte](https://github.com/etalab/licence-ouverte/blob/master/LO.md)) grants:

> « un droit non exclusif et gratuit de libre Réutilisation de l'Information […] à des fins commerciales ou non, dans le monde entier et pour une durée illimitée »

and explicitly allows to « la diffuser, la redistribuer, la publier et la transmettre, de l'exploiter à titre commercial […] ou en l'incluant dans votre propre produit ou application ».

**Inference:** a free or paid iOS app may embed constants derived from REFMAR observations. There is no royalty, no contract, no declaration, and no annual renewal. This removes the Annexe 7 / 35 % question entirely.

### 1.2 Obligations

**Fact** — the licence requires:

1. **Attribution:** « mentionner la paternité de l'Information : sa source (a minima le nom du Concédant) et la date de la dernière mise à jour de l'Information réutilisée. »
2. **No official character:** the attribution « ne doit ni conférer un caractère officiel à la Réutilisation […] ni suggérer une quelconque reconnaissance ou caution par le Concédant ».
3. **No misleading:** the reuse « ne doit pas induire en erreur des tiers quant au contenu de l'Information, sa source et sa date de mise à jour. »

### 1.3 What is derived, and what is not

- The **observations** are the licensed information.
- The **harmonic constants** are our own computation on that information. They are a derived dataset, not a redistribution of the raw series. The licence permits this (« modifier », « adapter », « inclure dans votre propre produit »).
- The derived constants are **not** a SHOM prediction. SHOM's official predictions come from its own model and its own validation chain; our least-squares fit does not inherit that status.

### 1.4 Attribution in the app

**Required string** (Settings → About, dataset detail, and the legal page):

> **Source : REFMAR / Shom — Licence Ouverte 2.0 — données mises à jour le <date de dernière mise à jour>**
> Modèle harmonique local calculé par Forge Digitale Solutions. Estimation, non validée par le Shom.

- `<date>` is the `retrievedAt`/`lastUpdate` recorded in the dataset, not the build date.
- The string appears in French; the English build may add an English translation, but the French source line stays.
- **No SHOM logo.** The licence does not grant trademark rights, and the « no official character » clause forbids implying endorsement.
- The app must not say « données officielles », « prédictions SHOM », or « marées SHOM ».

### 1.5 Paid SHOM products

They are **not** part of the route. The factual analysis is kept in **Appendix A** (« hors budget — non recommandé ») so that a future budget decision does not require re-research. Nothing in the app depends on it.

---

## 2. Data access

### 2.1 Endpoints

| Purpose | Endpoint | Auth | Limit |
|---|---|---|---|
| Station inventory | `GET https://services.data.shom.fr/maregraphie/service/tidegauges/` | none | 176 stations, JSON |
| Station metadata | `GET https://services.data.shom.fr/maregraphie/service/completetidegauge/{id}` | none | JSON, events, vertical ref |
| Observations, short pull | `GET https://services.data.shom.fr/maregraphie/observation/{id}/…` | none | **31 days per request** |
| Observations, long pull | `POST https://services.data.shom.fr/maregraphie/dl/observations` | none | asynchronous, contact fields |

**Fact** — the 31-day limit is stated on the REFMAR service page: « le téléchargement par flux des observations est limité à 31 jours par requête. Pour télécharger plus de 31 jours de données à la fois, utilisez la requête de téléchargement asynchrone (`/dl/observations`). »

**Fact** — the asynchronous payload accepted by the service is JSON with `tideGauges`, `sources`, `start`, `end`, `type` (`txt` or `json`), `name`, `mail`, `isContact`. A `CSV` type returns HTTP 400. The request carries a contact name and email; whether a real address is mandatory is **not verified**.

### 2.2 Source types 1–4

**Fact** — the data.gouv.fr description of the RONIM dataset defines four products:

| Index | Product | Resolution | Validated | Use in Estran |
|---|---|---|---|---|
| **1** | Brutes haute fréquence | 1 min | **No** | QC cross-check only |
| **2** | Brutes temps différé | 10 min | **No** | Not used |
| **3** | Validées temps différé | 10 min | **Yes** | Extrema cross-check |
| **4** | Validées horaires | 1 h | **Yes** | **Fit series** |

**Fact** — the hourly validated series is produced « à partir du filtre de Vondrak avec une pondération triangulaire. En cas de lacune d'observation supérieure à 1,5 heure, la hauteur horaire ne peut pas être calculée. » Consequence: a gap in source 4 is not noise, it is a documented absence; the generator must not interpolate across it silently.

**Inference:** source 4 is the right fit input because it is validated and evenly spaced. Source 3 is useful for extrema because it has 10-min resolution, but the POC shows it is **worse** for extrema timing (flat tops, noise). Source 1 is raw and must never be the sole fit input.

### 2.3 Time base and datum

- **Time:** all series in **UTC**. The API returns ISO-8601 UTC timestamps.
- **Vertical reference:** metres above the station's **`zero_hydrographique`**. The metadata gives `verticalRef.nom_ref` (IGN69) and `verticalRef.zh_ref` (the offset between chart datum and IGN69).
- **Rule:** never compare two stations, or a station and a SHOM table, without checking `zh_ref` first. The values are station-specific (15 and 297 share −2.831; 190 is −1.98; Brest is −3.635).

---

## 3. Stations

### 3.1 Primary and secondary stations

**Fact** — metadata from `completetidegauge`, 2026-10-26:

| Role | Station | `shom_id` | Network | State | Lat / Lon | `zh_ref` (IGN69) | Mean level | npbma | nphma |
|---|---|---|---|---|---|---|---|---|---|
| Ocean fit | `PORT-BLOC` | **15** | RONIM | **KO** (real-time) | 45.5685 / −1.0616 | −2.831 | 3.29 m | 0.54 | 5.9 |
| Ocean QC | `PORT_BLOC_GPM` | **297** | REFMAR | OK | 45.5684 / −1.0615 | −2.831 | 3.29 m | 0.54 | 5.9 |
| Bassin fit | `ARCACHON_EYRAC` | **190** | RONIM | OK | 44.6650 / −1.1636 | −1.98 | 2.48 m | −0.08 | 4.91 |
| National coefficient | `BREST` | **3** | RONIM | OK | 48.3829 / −4.4950 | −3.635 | 4.14 m | 0.25 | 7.93 |
| Secondary | `LA_PALMYRE` | 6327 | REFMAR | OK | 45.6593 / −1.1461 | not verified | — | — | — |
| Secondary | `RICHARD` | 150 | REFMAR | OK | 45.4537 / −0.9231 | not verified | — | — | — |
| Secondary | `LAMENA` | 191 | REFMAR | OK | 45.3356 / −0.7952 | not verified | — | — | — |

`npbma` / `nphma` are the lowest/highest astronomical tide levels above chart datum. They are **not** the mean spring range; do not use `nphma − npbma` as `meanSpringRange` without checking the definition.

### 3.2 Station/source selection rule

1. **Prefer validated sources (3/4) over raw (1/2).** A raw series may contain spikes, flatlines and datum jumps.
2. **`PORT-BLOC` 15:** fit on **source 4** (hourly validated). Use **297 source 1** only as an independent QC cross-check. **Exclude 2024** from 15 until the anomaly is explained (§3.3).
3. **`ARCACHON_EYRAC` 190:** fit on **source 4**; use **source 3** for an extrema sensitivity check.
4. **`BREST` 3:** fit on **source 4** for the national coefficient (§4.6).
5. **Reject a station-year** that fails the QC rule of §4.4, and record the rejection in the dataset metadata.

**Why 15 and not 297 for the fit:** 15 has validated history (sources 3/4, 2022–2025) even though its real-time state is KO. 297 is marked OK but exposes **only raw source 1** — it has no validated series. The v2 table (« 15 out of order — do not use », « 297 OK ») was misleading; it is corrected here.

### 3.3 The 2024 anomaly at station 15

**Measured** — exact-hour comparison of 15 source 4 vs 297 source 1 (same site, same `zh_ref`):

| Year | Mean difference | SD | Max absolute difference |
|---|---|---|---|
| 2023 | −0.0276 m | 0.0224 m | 0.984 m |
| **2024** | **−0.1922 m** | **0.9323 m** | **7.467 m** |
| 2025 | −0.0288 m | 0.0168 m | 0.286 m |

**Inference:** 2023 and 2025 agree to ~3 cm; 2024 is a different series. The station log supports a physical cause:

- **Fact** — 2024-06-26, station 15: « Suspicion d'envasement du puits. Intervention de notre partenaire semaine 27. »
- **Fact** — 2024-07-03, station 15: « Problème lors du nettoyage du puits : le barre servant au curage est restée figée en bas du puits. Une intervention de plongeurs est requise. »
- **Fact** — station 297 also had sensor outages in 2024 (14–17 June, radar failure in December), so 2024 is a bad cross-check year on both sides.

**Decision:** exclude **2024** from the 15 fit and from the 15↔297 comparison. The exclusion is documented in the dataset (`excludedYears: [2024]`, `exclusionReason`). Do not interpolate across it.

### 3.4 Secondary stations

`LA_PALMYRE` (6327), `RICHARD` (150) and `LAMENA` (191) are estuary/north-Médoc gauges. They are **not** fit inputs for the ocean or Bassin spots: the estuary is a different regime. They may be used for a regional consistency check (same storm, same surge sign) once their vertical references are verified. Their `zh_ref` is **not verified** — do not compare them to 15/190 before checking.

---

## 4. Harmonic analysis specification

### 4.0 Verified access path (2026-10-27)

**Fact — working endpoint**, no key, no account, no purchase:

```
GET https://services.data.shom.fr/maregraphie/observation/json/{station}
    ?sources={1|3|4}&dtStart=YYYY-MM-DD&dtEnd=YYYY-MM-DD
```

```json
{"data":[{"idstation":190,"idsource":4,"value":1.187,"timestamp":"2025/01/01 00:00:00"}, …]}
```

**Three traps, each verified by execution:**

1. **The 31-day limit is silent.** `dtStart=2025-01-01&dtEnd=2025-03-01` returns **HTTP 200** with data stopping at `2025-02-01`. It is a truncation, not an error. `scripts/tides/refresh` chunks into ≤ 31-day windows **and fails** when the last timestamp does not reach the requested end.
2. **Timestamps are not ISO-8601**: `YYYY/MM/DD HH:MM:SS`, in UTC. A dedicated parser is required.
3. **Heights use the station's vertical reference** (`zero hydrographique`). `completetidegauge/{station}` returns `npbma`, `nphma`, `niveau_moyen` and `verticalRef.zh_ref`, which the QC range check needs.

**Routes rejected by measurement** (recorded so they are not retried): `/maregraphie/service/dl/observations` → **404 on GET, POST, PUT and every path variant**; the `data.gouv.fr` REFMAR datasets expose **0 resources**; `/dl/observations` is the asynchronous export path (by email) and is not needed — the GET stream covers the whole history in a loop.

**Other verified routes:** `/maregraphie/service/tidegauges/` (index, 176 stations), `/maregraphie/service/completetidegauge/{id}` (metadata, `npbma`/`nphma`/`zh_ref`), `/maregraphie/dl/tidegauges` (index + per-source statistics), `/maregraphie/observation/nth/{id}?sources=4&limitValue=N` (last N values).

**Source availability measured on 2026-10-27** (source 4, validated hourly):

| Station | First | Last | Values |
|---|---|---|---|
| **190** ARCACHON_EYRAC | 1967-11-27 | 2026-06-30 | 223 892 |
| **15** PORT-BLOC | 1959-04-18 | 2026-06-15 | 327 961 |
| **3** BREST | 1846-01-04 | 2026-06-30 | 1 439 865 |

Station 15 is flagged `state: KO` in the index but still serves validated source 4 up to 2026-06-15; the flag is a live-transmission state, not an archive gap.

### 4.1 Model

```
h(t) = Z0 + Σ_i  H_i · cos(ω_i · t − g_i)
```

- `t` = UTC hours since the model epoch **2000-01-01T00:00:00Z** (`946_684_800` Unix seconds), matching `HarmonicPredictor.epoch`.
- `Z0` = mean sea level above chart datum, in metres.
- `H_i` = amplitude, `g_i` = phase **at the epoch**, in degrees.
- **No nodal terms in the baseline.** The engine implements `f = 1`, `u = 0`; the generator must output constants in **this convention**, not raw Greenwich phase lags. A published `G_i` must be converted with the equilibrium argument at the epoch.
- This is a single convention, not two. §4.3 defines the horizon that replaces nodal corrections.

### 4.2 Constituents

**Supported by the engine** (25 symbols in `ConstituentSpeeds`, verified by `testCompoundAndLongPeriodConstituentsAreSupported`):
`SA SSA M2 S2 N2 K2 2N2 MU2 NU2 L2 T2 K1 O1 P1 Q1 2Q1 RHO1 M1 J1 OO1 S1 M4 MN4 MS4 M6`

**Required set for the dataset** (the POC set plus shallow-water and long-period terms):
`M2 S2 N2 K2 K1 O1 P1 Q1 M4 MS4 MN4 M6 2N2 MU2 NU2 L2 T2 J1 OO1 2Q1 RHO1 M1 S1 SA SSA`

**Status:** the former gap is **closed**. `MN4`, `2Q1`, `RHO1` and `M1` were added to `ConstituentSpeeds`, with a unit test per symbol; the full package suite passes (100 tests). This is no longer a B5 blocker.

**Rule:** a constituent dropped from the dataset must be listed in `droppedConstituents` with a reason. Do not silently reduce the set.

### 4.3 Nodal corrections and validity horizon

**Fact:** the 18.6-year lunar node cycle modulates amplitude and phase. The baseline engine does **not** implement `f`/`u`; it stores the constants as fitted and predicts with `f = 1`, `u = 0`.

**Specification (baseline, M1):**

- The dataset declares `"nodalCorrections": false`. The loader **rejects** `true`, because the engine cannot apply `f`/`u`; silently accepting it would mispredict.
- The dataset must declare `"validUntil"` on every station: the fit end **+ 3 years**. The fit ends in 2026-H1, so the shipped horizon is 2029-06-30 / 2029-06-15.
- `TideEngine.state(for:at:)` throws `TideError.outsideValidity` when `date > validUntil`. There is no silent prediction beyond the horizon.
- The app, widgets and Live Activity must surface the horizon: outside it, the verdict is unavailable, not « Oui ».

**Why +3 years:** over a 2–3 year fit the nodal modulation is small; beyond ~3 years it is no longer negligible. The horizon is a **contract**, not an accuracy claim. If the annual refresh rolls the fit forward, the horizon rolls forward with it.

**Future route (not M1):** implement the standard `f`/`u` factors per constituent family, set `"nodalCorrections": true`, bump the schema version, and remove or relax `validUntil`. Do not claim a 10-year horizon without them.

**Measured expectation:** the POC (no nodal corrections, 19 constituents) already reaches 16–18 cm RMSE. Nodal corrections are a correctness requirement for long horizons, not the main lever on the 2025 test. The dominant residual is weather surge and shallow-water effects (§6.3).

### 4.4 QC rule

Apply to every station-year before the fit:

| Check | Rule | Action on failure |
|---|---|---|
| Range | height within `[npbma − 0.5 m, nphma + 0.5 m]` | flag, inspect |
| Rate of change | `\|dh/dt\| ≤ 1.5 m/h` on hourly series | reject the point |
| Spike | point differs from the 3-point median by > 1.0 m | reject the point |
| Flatline | ≥ 6 consecutive identical hourly values | reject the run |
| Gap | any gap > 1.5 h in source 4 | do not interpolate; split the fit window |
| Datum continuity | monthly median of residuals stable within 0.10 m | reject the station-year |
| Coverage | ≥ 90 % of hours in the fit window | reject the station-year |

Thresholds are **proposed**; they must be calibrated on the 2022–2025 series and recorded in the generator config. A rejected station-year is not silently dropped: it appears in `qc.rejected` with the failed check.

### 4.5 Fit windows

**Measured availability made the original windows too short.** A fit ending in 2024 produces a model that is already three years stale at launch, and the 2026 half-year was measured **above the accuracy target** when left out of sample at 190 (RMSE 0.2167 m, bias −0.0754 m, 2026-01-01 → 2026-06-30). The windows are therefore **rolled forward** with the validated 2026 data; **2025 stays held out** and is never in any fit.

| Station | Fit | Test (held out) | Excluded | Reason |
|---|---|---|---|---|
| **190** `ARCACHON_EYRAC` | 2022-01-01 → 2024-12-31 **+ 2026-01-01 → 2026-06-30** | 2025-01-01 → 2025-12-31 | — | 2025 held out; 2026 makes the model current at launch |
| **15** `PORT-BLOC` | 2022-01-01 → 2023-12-31 **+ 2026-01-01 → 2026-06-15** | 2025-01-01 → 2025-12-31 | **2024** | Silt/plumbing anomaly (§3.3); the 2026 extension keeps the horizon alive |
| **3** `BREST` | 2022-01-01 → 2024-12-31 **+ 2026-01-01 → 2026-06-30** | 2025-01-01 → 2025-12-31 | — | National coefficient only |

**Horizon.** `validUntil` = fit end + 3 years for every station (Z28): **2029-06-30** for 190 and 3, **2029-06-15** for 15. Fitting 15 on 2022–2023 alone would have set a 2026-12-31 horizon — two months after this run — and silently switched a shipped spot to `.dataUnavailable`. The extension is what prevents that.

**Why a backward hold-out is still valid.** Training on 2022–2024 + 2026 and testing on 2025 is not leakage: 2025 contributes no sample to the fit. It is the same protocol as the planned “fit 2023–2025, test 2026”, only reversed, and it is the only way to test a model that must be current at launch.

**Next refresh.** Roll to fit 2024–2026, test 2027, once validated 2027 data exists.

### 4.6 Coefficient de marée — defect and fix

**Fact:** the French coefficient is defined at **Brest**: `C = (H_h − H_b) / U × 100`, with `U = 6.10 m` (mean spring range at Brest), clamped to 20…120. It is then treated as identical along the Atlantic and Channel coasts.

**Defect:** `HarmonicPredictor.coefficient(for:on:)` computes `range / station.meanSpringRange × 100` using the **local** station's range. At Arcachon this yields a local ratio, not the national coefficient. Two consequences:

1. the displayed coefficient can differ from the official one by several points;
2. the current pass-current gate (`coefficient ≥ 100`) is applied to a local proxy, so its threshold is not the intended national threshold.

**Fix:**

- Fit **Brest station 3** (REFMAR, free) with the same pipeline.
- Compute `C = round((H_h − H_b) / 6.10 × 100)`, clamped 20…120, once per civil day in Europe/Paris.
- Store the Brest model in the same dataset (`role: "coefficientReference"`).
- Validate against a **manual sample** of published coefficients from the Annuaire des marées (no scraping); target: exact match or ±1 for ≥ 90 % of sampled days.
- Until the fix ships, the UI must label the value **« coefficient local estimé »**, not « coefficient de marée ».

**`meanSpringRange` contract (review Z9).** The local station field is the **fitted mean spring range**, not `nphma − npbma`. For the baseline dataset it is computed from the fitted constants as:

```
meanSpringRange = 2 · (H(M2) + H(S2))
```

`TidalStation.derivedMeanSpringRange` implements this; `testDerivedMeanSpringRangeUsesM2AndS2` covers it. If the generator uses a fitted spring range instead, it must record the method in the dataset metadata and still write a positive value. `nphma − npbma` is an extreme range (≈ 4.99 m at 190, ≈ 5.36 m at 15) and **must not** be used. The validator rejects `≤ 0`, so a generator that writes `0.0` fails at load time. This is a data-contract rule, not a coefficient claim: the national coefficient remains Brest-based.

**Inference:** this is a small, free change (one more station fit) and it removes a safety-relevant inconsistency. It is an M1 blocker for the current gate, not an M2 refinement.

### 4.7 Outputs and dataset contract

The generator writes one file: `tide-model-<year>.<revision>.json`.

```json
{
  "schemaVersion": 6,
  "source": "REFMAR / Shom",
  "license": "Licence Ouverte 2.0",
  "licenseURL": "https://github.com/etalab/licence-ouverte/blob/master/LO.md",
  "sourceDatasets": [
    "https://www.data.gouv.fr/datasets/reseaux-de-reference-des-observations-maregraphiques-refmar-maregraphes-ronim",
    "https://www.data.gouv.fr/datasets/reseaux-de-reference-des-observations-maregraphiques-refmar-maregraphes-partenaires"
  ],
  "retrievedAt": "2026-10-26T00:00:00Z",
  "sourceLastUpdate": "2026-02-24",
  "official": false,
  "method": "least-squares harmonic analysis",
  "epoch": "2000-01-01T00:00:00Z",
  "datum": "zero_hydrographique",
  "units": "m",
  "nodalCorrections": false,
  "constituents": ["M2", "S2", "N2", "K2", "K1", "O1", "P1", "Q1", "M4", "MS4", "MN4", "M6", "2N2", "MU2", "NU2", "L2", "T2", "J1", "OO1", "2Q1", "RHO1", "M1", "S1", "SA", "SSA"],
  "stations": [
    {
      "id": "190",
      "name": "ARCACHON_EYRAC",
      "role": "bassinReference",
      "coordinate": {"latitude": 44.66500092, "longitude": -1.16355002},
      "timezoneIdentifier": "Europe/Paris",
      "verticalReference": {"name": "IGN69", "zhRef": -1.98},
      "meanSeaLevel": 0.0,
      "meanSpringRange": 0.0,
      "meanSpringRangeMethod": "2*(M2+S2)",
      "constituents": [{"symbol": "M2", "amplitude": 0.0, "phaseDegrees": 0.0}],
      "fitWindow": ["2022-01-01", "2024-12-31"],
      "testWindow": ["2025-01-01", "2025-12-31"],
      "excludedYears": [],
      "qc": {"status": "pass", "rejected": []},
      "validUntil": "2029-06-30T23:59:59Z",
      "nodalCorrections": false,
      "attribution": "Source : REFMAR / Shom — Licence Ouverte 2.0",
      "accuracy": {
        "rmse": 0.0, "mae": 0.0, "bias": 0.0,
        "extrema": {
          "high": {"medianMinutes": 0.0, "p95Minutes": 0.0, "maxMinutes": 0.0, "p95HeightMeters": 0.0, "maxHeightMeters": 0.0},
          "low":  {"medianMinutes": 0.0, "p95Minutes": 0.0, "maxMinutes": 0.0, "p95HeightMeters": 0.0, "maxHeightMeters": 0.0}
        }
      }
    }
  ],
  "spots": [
    {
      "id": "pointe-de-grave",
      "stationId": "15",
      "correction": {"lagMinutes": 0, "amplitudeFactor": 1.0},
      "correctionStatus": "none",
      "validation": "gauged",
      "uncertainty": {
        "timeMinutes": 45,
        "heightMeters": 0.60,
        "basis": "u_t: max |dt| 37.27 min + 10 min allowance (D2) = 47.27 min; u_h: leave-one-year-out max under-prediction 0.5113 m (2022) + 0.05 m minimum allowance (D2); declared 0.60 m (margin 0.0887 m)"
      }
    },
    {
      "id": "arcachon-eyrac",
      "stationId": "190",
      "correction": {"lagMinutes": 0, "amplitudeFactor": 1.0},
      "correctionStatus": "none",
      "validation": "gauged",
      "uncertainty": {
        "timeMinutes": 70,
        "heightMeters": 0.60,
        "basis": "u_t: max |dt| 47.79 min + 10 min allowance (D2) = 69.80 min; SHOM 2025 low-water max 57.8 min + 12 min allowance (Z19); u_h: leave-one-year-out max under-prediction 0.6059 m (2022) + 0.05 m minimum allowance (D2); declared 0.70 m (margin 0.0941 m)"
      }
    }
  ],
  "checksum": "sha256:..."
}
```

**Rules:**

- `schemaVersion` is `6`. A schema change requires a version bump.
- `official` is always `false`. No field may imply SHOM validation; the loader rejects `true`.
- `validUntil` is **required on every station** and at the top level. The loader rejects a dataset with a null station horizon; `TideEngine` throws `outsideValidity` past it. The baseline has no nodal corrections, so the horizon is a hard gate.
- `nodalCorrections` is `false`. The loader rejects `true`, because the engine cannot apply `f`/`u`.
- `meanSpringRange` is the fitted mean spring range, `2 · (M2 + S2)` for the baseline (or a documented fitted equivalent). It must be `> 0`. **Never** `nphma − npbma`.
- `accuracy` is filled from the held-out run, never from the fit residual. `maxHeightMeters` is required at every extremum; a p95 alone is not a bound.
- **v1 catalog: exactly the 2 gauged spots.** `spots[].validation` must be `gauged`; the loader **rejects** `estimatedOpenCoast` and `estimatedLagoon` (Z17). The enum cases stay for the post-v1 catalog.
- `spots[].correctionStatus` must be `none` in v1; the loader rejects `calibrated` and `estimated`.
- `spots[].correctionStatus` is one of `none`, `calibrated`, `estimated`. `none` with `lagMinutes: 0, amplitudeFactor: 1.0` is **not** an identity claim: it means no local correction is known, and the uncertainty envelope carries the risk. Only `calibrated` may present the correction as validated.
- `uncertainty` is the gate input (§7.3), not a marketing tolerance. `basis` records its derivation. It must be **active** (`timeMinutes > 0 || heightMeters > 0`); the loader rejects `0 / 0` (Z17). `u_t` and `u_h` are per station and generated from the measured bounds (§6.5, Z21/Z22).
- `label` is computed from `validation` and the reference station (`Spot.modelLabel`), not stored as free text.
- The checksum covers the canonical JSON (sorted keys, no whitespace variance).
- The loader contract is tested end-to-end by `TideModelLoaderTests` (JSON → `TidalStation` → `TideEngine` → known date), including the horizon, the `official` flag, unknown station references and the `correctionStatus` distinction.

### 4.8 Reproducibility

`scripts/tides/refresh` must:

1. download the station list and the observation series (31-day chunks or async);
2. apply the QC rule and write a QC report;
3. fit the constants and write the dataset;
4. run the held-out validation and refuse to write a dataset that fails §6.4;
5. print the attribution string and the source dates;
6. be deterministic: same inputs → same checksum (fixed iteration order, fixed float formatting).

A failed run leaves the previous dataset untouched and exits non-zero. CI runs the validation against a small committed fixture, not against the network.

---

## 5. Validation protocol

### 5.1 No leakage

The test year is never in the fit. The generator must assert that the fit and test windows are disjoint. Do not validate the model against `maree.shom.fr` or against a SHOM table: that would test SHOM's model, not ours.

### 5.2 Metrics

| Family | Metrics |
|---|---|
| Height series | RMSE, MAE, bias (model − observation), on the hourly grid |
| Extrema | median, p95, **max** of `\|Δt\|` and `\|Δh\|`, high and low separately |
| Coverage | number of matched extrema / number of observed extrema |
| Envelope | the bound used by the gate, with its derivation (max + allowance), per validation class |

**Max is mandatory.** The envelope is a bound; a p95 cannot validate it. A release run that omits `maxHeightMeters` or `maxMinutes` is rejected by the dataset contract.

The height metrics compare the **astronomical model** to the **total observed level**. The calm-weather subset (§5.5) is the closest proxy to the astronomical component; the full series is what the app actually faces.

### 5.3 Extrema detector

- Detect local maxima/minima on the **hourly validated** series (source 4), with a minimum separation of 3 h.
- Refine each extremum by a 3-point parabolic fit on the hourly neighbours.
- Match each predicted extremum to the nearest observed extremum of the same kind within **±60 min**. If none, count it as unmatched (do not drop it silently).
- Report the number of unmatched extrema separately: a model that misses an extremum is worse than one that is 20 min late.

### 5.4 Sampling rule

- The **extrema claim** uses the hourly validated series. It is the series the model is fitted on and the one users' decisions are based on.
- The **10-min series** (source 3) is a sensitivity check only. The POC shows it is worse for extrema (median 15–17 min, p95 43–48 min): flat tops and noise around slack water. Do not use it to claim a better accuracy.
- The **height RMSE** uses the hourly grid. Interpolating the model to 10-min observation timestamps adds interpolation error without adding information.

### 5.5 Calm-weather subset

The raw residual includes meteorological surge, which no harmonic model can remove. Report two numbers:

1. **Full series** — what the app will actually face.
2. **Calm-weather subset** — exclude days with strong wind or a pressure anomaly.

Under 0 €, the calm-weather flag can come from the free Open-Meteo historical API (wind speed at 10 m, mean sea-level pressure) at the station coordinates. The exact threshold is **not verified**; propose `wind < 15 km/h` and `|pressure − 1013 hPa| < 10 hPa` for the first run, and record the rule in the report. If the API is unavailable, report the full series only and say so.

### 5.6 What cannot be claimed

- **±15 cm on total water level.** The astronomical model's RMSE is 16–18 cm; surge adds more. The app's gates use a margin, not a ±15 cm promise.
- **±15 min at ungauged spots.** No observation exists there.
- **Officiality.** The model is ours; SHOM has not validated it.

---

## 6. Measured accuracy (proof of concept)

### 6.1 Results

**Measured** — least-squares fit, 19 constituents, epoch 2000-01-01, UTC, `zero_hydrographique`, no nodal corrections, no calm-weather filter:

> **Baseline, not release data.** These numbers come from the reviewer's proof of concept. The release dataset must be re-fitted with the full constituent set, the QC rule and the Brest reference model, and the accuracy report must show the new numbers. Do not ship the POC constants.

| Station | Series | Fit | Test | RMSE | MAE | Bias | High median / p95 / max | Low median / p95 / max |
|---|---|---|---|---|---|---|---|---|
| **190** | source 4 hourly | 2022–2024 | 2025 | **0.1752 m** | 0.1339 m | −0.0164 m | **7.0 / 22.6 / 33.8 min** | **8.9 / 27.6 / 35.0 min** |
| **190** | source 3 10-min | 2022–2024 | 2025 | — | — | — | 15.5 / 43.6 / — min | 16.3 / 48.3 / — min |
| **15** | source 4 hourly | 2022–2023 | 2025 | **0.1601 m** | 0.1189 m | −0.0316 m | **4.4 / 16.3 / 28.5 min** | **6.1 / 19.8 / 28.8 min** |
| **15** | source 3 10-min | 2022–2023 | 2025 | — | — | — | 16.2 / 43.5 / — min | 17.2 / 46.2 / — min |

Height error at extrema (p95): 190 high 0.353 m / low 0.357 m; 15 high 0.296 m / low 0.298 m. Median height error at extrema: 190 0.086 / 0.166 m; 15 0.078 / 0.106 m.

**Max `|Δh|` — not retained by the POC artifact.** The POC retained p95 heights but not the maximum, so v4 cannot publish a measured max. This is an explicit gap, not a hidden p95:

- the release run **must** publish `maxHeightMeters` at every extremum (dataset contract, §4.7);
- until then, the height bound (§6.5) is derived conservatively from the p95 plus a stated allowance, and it is labelled as such;
- the max `|Δt|` values **are** known and already exceed the 30-minute p95: 33.8 min (190 high), 35.0 min (190 low), 28.5 / 28.8 min (15). That is exactly why the gate uses a bound, not the p95.

### 6.2 What the numbers mean

- **Extrema timing:** median 4–9 min, p95 16–28 min on hourly data. The old ±15 min target is met at the median but **not at p95**. The 10-min series is clearly worse (p95 43–48 min).
- **Height:** RMSE 16–18 cm. A ±15 cm target is **not met** even before surge.
- **Bias:** −1.6 to −3.2 cm, small and consistent. It can be absorbed by `Z0` but must be reported.
- **Station 15 vs 190:** 15 is slightly better on timing and RMSE, despite the 2024 exclusion. Both are usable.

### 6.3 Why the residual is not just "a better fit"

The remaining error has three sources:

1. **Meteorological surge** — wind and pressure, 10–50 cm, not harmonic. No constituent set removes it.
2. **Shallow-water / local bathymetry** — especially in the Bassin; MN4/M6 and higher terms help, but a 1-D harmonic model cannot capture the full lagoon response.
3. **Fit/observation mismatch** — the Vondrak hourly filter smooths the signal; extrema timing is sensitive to it.

Adding nodal corrections and four constituents may improve the long-horizon behaviour, but it is unlikely to bring p95 below 15 min at both stations. The target must be revised, not the result massaged.

### 6.4 Proposed pass/fail target (D2)

For **gauged stations**, on the hourly validated series, held-out year:

| Metric | Target | POC 190 | POC 15 |
|---|---|---|---|
| Median `\|Δt\|` | ≤ 10 min | 7.0 / 8.9 | 4.4 / 6.1 |
| p95 `\|Δt\|` | ≤ 30 min | 22.6 / 27.6 | 16.3 / 19.8 |
| Max `\|Δt\|` | ≤ 45 min | 33.8 / 35.0 | 28.5 / 28.8 |
| RMSE | ≤ 0.20 m | 0.1752 | 0.1601 |
| `\|bias\|` | ≤ 0.05 m | 0.0164 | 0.0316 |
| p95 `\|Δh\|` at extrema | ≤ 0.40 m | 0.353 / 0.357 | 0.296 / 0.298 |

**Rationale:** the app's decision grid is 30 min. A p95 of 30 min means the window boundary can be off by one slot; the gate margin (§7.3) absorbs it. A 15-min p95 would be better but is not supported by the evidence. The target is a **release gate**, not an aspiration.

**Withdrawn claims:** ±15 min p95, ±15 cm total level, any accuracy claim at ungauged spots.

**For ungauged spots:** no pass/fail target. They are `estimation` and their uncertainty envelope drives the gate.

### 6.5 Envelope derivation (D6) — measured, one-sided (v6)

**v1 scope (D3 = Option A):** only the two gauged stations ship, so the envelope is set **per station**.

| Station | `u_t` | `u_h` | Derivation (generated in `uncertainty.basis`) |
|---|---|---|---|
| **15** — Pointe de Grave / Le Verdon | **75 min** | **0.60 m** | `u_t = LOYO max |dt| 64.76 (2023) + 10` = 74.76 → declared 75. `u_h = LOYO max 0.5113 (2022) + 0.05` = 0.5613 → declared 0.60. |
| **190** — Arcachon-Eyrac | **70 min** | **0.70 m** | `u_t = LOYO max |dt| 53.33 (2024) + 10 = 63.33`; Z19 SHOM 2025 `57.8 + 12 = 69.8` is stricter, so 70. `u_h = LOYO max 0.6059 (2022) + 0.05` = 0.6559 → declared 0.70. |

**`u_h` is one-sided and sized on the series (Z21/Z27).** The boating gate fails open only when the prediction is **too high**, so the bound is `max(pred − obs) + 0.05 m`, not `max |Δh|`. The old 0.9431 m at 190 was the 2025-01-28 storm surge in the **safe** direction (observed higher than predicted).

A single neutral year (2025) does not bound the series: an anticyclonic winter makes the model run too high. The dataset now publishes a **leave-one-year-out** table — for each year, the model is refitted without it and evaluated on it. Worst under-prediction: **190 0.6059 m (2022)**, **15 0.5113 m (2022)**. That is what sizes `u_h = 0.70 / 0.60 m`; the `basis` names the worst year. `maxUnderPredictionMeters` and `minOverPredictionMeters` are published; `maxAbsoluteErrorMeters` is information only and is never subtracted from a height. Product cost at 190 (tide only, 0.5 m draught): **80.8 % of hours** at 0.70 m, against 84.5 % at 0.60 m.

**D2 is a consistency rule (Z22/Z29/Z30), not an absolute minute count.** For every shipping station, on the held-out year and on every leave-one-year-out year:

> median `|Δt|` ≤ 12 min, p95 ≤ 35 min, max `|Δt|` ≤ `u_t` − 10 min (on the **worst LOYO year**);
> `|bias|` ≤ 0.05 m, p95 `|Δh|` ≤ 0.40 m, max under-prediction ≤ `u_h` − 0.05 m (worst LOYO year);
> **RMSE is a series property**: LOYO median ≤ 0.20 m and no year above 0.22 m.

The generator **aborts** if a declared envelope does not cover the measurement. `u_t(15) = 75` replaces 55: the LOYO worst year (2023) has a 64.76 min error, so the pêche à pied `Oui` window at Pointe de Grave narrows to ≈ 45 min around low water. `u_t(190) = 70` is kept because the SHOM cross-check (69.8) is stricter than the LOYO rule (63.33).

**Horizon (Z26/Z28).** `validUntil` is **fit end + 3 years** for every station: **2029-06-30** (190, 3) and **2029-06-15** (15). The horizon bounds **astronomical decay** (nodal drift ±1.5 % over 2022→2029, ≈ 0.05–0.07 m), not annual weather dispersion — that is `u_h`'s job. The 2026-H1 stress test is **not** a horizon measurement: January 2026 mean pressure at Arcachon was **1007.9 hPa** against **1027.6 hPa** in January 2022 (≈ +0.20 m of sea level from atmospheric loading); January 2025 was neutral at 1016.8 hPa. The stress-test bias (−0.077 / −0.109 m) is the weather anomaly, not model drift. The dataset is regenerated **once a year** as a maintenance ritual (`BUILD.md`); a skipped year does not brick the app.

**Coefficient (Z23).** The national coefficient is `C = clamp(round(range_Brest / 6.10 × 100), 20, 120)`. The local proxy (`range / meanSpringRange × 100`) ran ≈ 17 % high on 2025 (median 85.0 against a national 72.5). The Brest model is **not validated** (`coefficient.validated = false`): 382 published 2025 high waters give bias **+1.75 points**, 37 % within ±1, 57 % within ±2, max 7 (target ±1 for 90 %). Consequences:

- the coefficient is **not displayed** in v1 (no « coef 92 » anywhere);
- the pêche à pied gate is on the national scale at **72** (2-point margin);
- `SwimmingRule` now uses the **local predicted range** (`spot.swimmingRange`: `lowBelow` / `strongAt`) and the tide phase, not the national coefficient. The UI presents swimming as a **risk level** (`SwimmingRiskLevel`), never a « Oui »; the coefficient remains hidden and post-v1;
- the nodal drift (M2 factor 0.963 in 2025 → 0.997 in 2029, fit mean 0.985) is ±1.5 % around the fit mean, ≈ 0.05–0.07 m and 1–2 coefficient points, absorbed by `u_h = 0.70 / 0.60` and the 2-point gate margin.

**Swimming level (v11).** The swimming level uses the **local predicted range**, not the coefficient. `T` is the range reached on the same number of days as the national coefficient reaches 100 in 2025 (37 days): **3.880 m at 190**, **4.335 m at 15**. The grey band is `T ± 0.30 m`; the dataset publishes `swimmingRange: { lowBelow, strongAt }` per spot. `strong` at range ≥ `strongAt` **and** phase in 0.4…0.6; `moderate` at range ≥ `lowBelow` (the band, whatever the phase); `low` below. No `low` is possible inside the band. A missing range is `Courants non estimés` (`currentDataUnavailable`); a missing sea temperature is `.dataUnavailable` but no longer mutes the current level — it appears as « eau indisponible » in the conditions line.

**What these numbers are:** gate inputs, per station, generated from the run. **What they are not:** accuracy claims, a single number for all spots, or a claim about the post-v1 spots.

---

### 6.6 Measured accuracy of `tide-model-2026.1` (schema 6)

**Measured** on 2026-10-27 by `scripts/tides/refresh`, held-out year 2025, validated hourly source 4, extrema against validated 10-minute source 3. The 2025 sample is now **complete** (Z20): 8 760 hours at 190 and 3, 8 753 at 15 (two allowlisted source outages of 4 h and 5 h). Full table in [`accuracy-2026.1.md`](accuracy-2026.1.md).

| Station | n | RMSE (m) | Bias (m) | p95 \|Δh\| (m) | max under-pred. (m) | min over-pred. (m) | Low Δt med / p95 / max (min) | High Δt med / p95 / max (min) |
|---|---|---|---|---|---|---|---|---|
| **190** | 8 760 | 0.1605 | −0.0062 | 0.3146 | **0.5032** | −0.9436 | 11.62 / 32.17 / **50.00** | 10.00 / 31.67 / 52.14 |
| **15** | 8 753 | 0.1467 | −0.0144 | 0.2983 | **0.3926** | −0.7802 | 7.83 / 25.00 / 45.08 | 7.69 / 25.62 / 44.17 |
| **3** | 8 760 | 0.1475 | −0.0147 | 0.2907 | **0.4776** | −0.7505 | 6.99 / 17.86 / 30.50 | 7.29 / 17.32 / 37.68 |

**Leave-one-year-out (Z27).** For each year, the model is refitted without it and evaluated on it. The worst under-prediction sizes `u_h`:

| Station | 2022 | 2023 | 2024 | 2025 | 2026-H1 | `u_h` |
|---|---|---|---|---|---|---|
| **190** | **0.6059** | 0.5577 | 0.4910 | 0.5032 | 0.4741 | **0.70 m** |
| **15** | **0.5113** | 0.4637 | — (excluded) | 0.3926 | 0.4701 | **0.60 m** |
| **3** | 0.5005 | 0.5292 | 0.4774 | 0.4776 | 0.4537 | 0.60 m (no spot) |

**Leave-one-year-out max |Δt| (Z29).**

| Station | 2022 | 2023 | 2024 | 2025 | 2026-H1 | `u_t` |
|---|---|---|---|---|---|---|
| **190** | 50.00 | 52.50 | **53.33** | 52.14 | 53.28 | **70 min** |
| **15** | 58.20 | **64.76** | — (excluded) | 45.08 | 58.17 | **75 min** |
| **3** | 35.29 | 35.00 | 42.50 | 37.68 | 45.53 | 45 min (no spot) |

The 2023-08-24 event at station 15 (64.76 min) is a **plateau**, not a double high: the observed level stays within **4 cm of its maximum for ~100 min** (07:50 4.410, 08:00 4.370, 08:10 4.406, … 09:30 4.334), and the model's high at 08:54 lies inside it. The 64.76 min is the distance to the highest sample, not to a physical high. `u_t = 75` is kept because the 2023 **low-water** max is **63.21 min** — the year is genuinely the hardest of the LOYO series. The detector does not yet centre a 4 cm plateau; that is a non-blocking improvement for the next refresh (it would move the bound by ≈ 1.5 min at most). The pêche à pied `Oui` window at Pointe de Grave narrows to ≈ 45 min around low water.

**D2 check.** `|bias|` ✓, p95 ✓ at all three on the neutral held-out year. `max |Δt| ≤ u_t − 10` ✓ on the worst LOYO year (190 53.33 ≤ 60; 15 64.76 ≤ 65). Max under-prediction ≤ `u_h − 0.05` ✓ on 2025 (190 0.5032 ≤ 0.65; 15 0.3926 ≤ 0.55) **and** on the worst LOYO year (190 0.6059 ≤ 0.65; 15 0.5113 ≤ 0.55). RMSE series ✓ (median 0.180 / 0.165 / 0.162; max 0.209 / 0.208 / 0.189). The old absolute 45-min target is withdrawn: it conflated the target with the envelope and left zero allowance.

**QC (Z20).** Each request is a full 31-day span with an exclusive `dtEnd`; a gap > 1.5 h aborts the run unless the station allowlists it with dates and a source reason. Documented outages: 190 → 2024-10-08 06:00…2024-10-09 10:00 (28 h); 15 → 14 short summer outages in 2022–2023 plus 2025-06-27 (4 h) and 2025-06-29 (5 h); 3 → 2022-10-20 (5 h), 2024-06-19…21 (35 h), 2024-11-27…12-17 (**489 h**, confirmed on source 3 at 475.8 h).

**Model sanity.** Fitted `niveau moyen`: 2.537 m at 190 (SHOM `niveau_moyen` 2.48), 3.375 m at 15 (3.29), 4.262 m at 3 (4.14). Fitted `meanSpringRange = 2·(M2+S2)`: 3.44 m at 190, 3.92 m at 15, 5.48 m at 3.

---

## 7. Spot coverage

### 7.1 v1 catalog (D3 = Option A) — 2 gauged spots

**D3 was revised by Anthony on 2026-10-27: Option A.** v1 ships **two spots only**, both gauged. The 12 estimated spots leave the v1 catalog entirely — no « bientôt » entry, no display, no verdict. The envelope is per station (§6.5), and the loader rejects anything that is not gauged (`TideModel.validationError`, review Z17).

| # | Spot | Reference | `correctionStatus` | `validation` | Label | Envelope `u_t` / `u_h` |
|---|---|---|---|---|---|---|
| 1 | Pointe de Grave / Le Verdon | **15** (fit) + 297 (QC) | `none` | **`gauged`** | **modèle local — station 15** | **75 min / 0.60 m** |
| 2 | Arcachon (Eyrac) | **190** | `none` | **`gauged`** | **modèle local — station 190** | **70 min / 0.70 m** |

**Count:** v1 = **2 spots**, both `gauged`, both `correctionStatus: none`. `u_h = 0.60 m` (15) / `0.70 m` (190) and `u_t = 75 min` (15) / `70 min` (190) are leave-one-year-out bounds (Z21/Z27/Z29); `u_t(190) = 70 min` also covers the SHOM 2025 cross-check (§6.5, Z19).

**Why `correctionStatus: none` is not `lag 0`.** The schema serialises `{"lagMinutes": 0, "amplitudeFactor": 1.0}` for an absent correction, but `correctionStatus: none` says explicitly that no local correction is known. Only `calibrated` may present a correction as validated. For the two gauged spots no correction is applied or needed: the model is fitted on the station itself.

### 7.1b Post-v1 roadmap — the 12 estimated spots

These spots are **not shipped in v1** and are not part of the v1 dataset contract. They are kept here so the catalog can grow without re-deciding the model.

| # | Spot | Reference | `validation` (post-v1) | Envelope (post-v1, unvalidated) |
|---|---|---|---|---|
| 3 | Soulac-sur-Mer | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 4 | Montalivet-les-Bains | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 5 | Hourtin-Plage | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 6 | Carcans-Plage | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 7 | Lacanau-Océan | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 8 | Le Porge-Océan | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 9 | Lège / Grand Crohot | 15 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 10 | Cap Ferret | 190 (7 km) | `estimatedOpenCoast` | 75 min / 0.75 m |
| 11 | Pyla-sur-Mer | 190 | `estimatedOpenCoast` | 75 min / 0.75 m |
| 12 | Andernos-les-Bains | 190 | `estimatedLagoon` | 90 min / 0.90 m |
| 13 | Arès | 190 | `estimatedLagoon` | 90 min / 0.90 m |
| 14 | Gujan-Mestras / La Hume | 190 | `estimatedLagoon` | 90 min / 0.90 m |

**The lag interpolation / FES2022 work is stopped.** Under D3 = Option A no estimated spot ships, so there is nothing to calibrate in v1. The Architect's coastal-lag and FES2022 derivation is deferred to the post-v1 catalog; no value is invented here.

**Cap Ferret is not a lagoon.** It is an ocean-facing spot at the inlet mouth. The SHOM `CAP_FERRET` attached port (reference `ARCACHON_EYRAC`) differs from 190 by **+18 min at high water** (max +36) and **+0.21 m** (reviewer cross-check, 2025 HLT). It is `estimatedOpenCoast`, and its missing correction stays explicit.

**Pyla is not an identity.** It sits at the south pass, where the tide is distorted; SHOM has a separate `PILAT-PLAGE` correction site. Pyla is `estimatedOpenCoast` with `correctionStatus: none` until a pass correction is derived.

**The 12 spots are not all equal.** The seven open-coast spots (3–9) share the 15 reference; Cap Ferret (10) and Pyla (11) are inlet regimes with a measured distortion; the lagoon interior (12–14) has no gauge and no SHOM rattachement site. A single accuracy number for all spots is forbidden, and none of these bounds is validated.

### 7.2 Product decision (D3) — revised to Option A

**Option A — adopted by Anthony on 2026-10-27.** v1 ships **2 gauged spots only**: Pointe de Grave / Le Verdon and Arcachon-Eyrac. No estimated spot, no « bientôt » entry, no estimated verdict. The 12 other spots are a post-v1 roadmap (§7.1b). The loader enforces the decision: a non-gauged spot is rejected at load time (Z17).

**Option B — withdrawn.** It was adopted on 2026-10-26 (14 spots, 12 estimated, « estimation — modèle local »). The revision to A is a product decision, not a data finding: with two validated stations, shipping 12 unvalidated verdicts was judged too risky for v1.

**Option C — rejected.** Presenting the 12 as if they had the same accuracy as the gauged ones would be a false safety claim. No accuracy number is claimed at an ungauged spot.

### 7.3 Fail-closed gate policy (full interval, not corners)

For a spot with the bound `(±u_t minutes, ±u_h metres)` of §6.5, the gate evaluates the **whole interval** `[t − u_t, t + u_t]` at the decision sample `t`. It does not sample only the two corners.

1. **Water level.** `min h` over the interval, using the 10-minute curve **and** the exact `current`/`next` event heights (a low water between two curve samples is not missed), minus `u_h`. If the result is below the spot's draught, the sample is blocked. If the nominal height passes but the conservative height does not, the blocker is `.insufficientMargin` (« Marge insuffisante »); otherwise `.waterLevel`.
2. **Timing (pêche à pied).** The **maximum** distance, over every instant in the interval, to the nearest low water (events from the exact extrema plus the curve-derived extrema). If it exceeds 120 min, the sample is blocked; nominal inside / interval outside → `.insufficientMargin`.
3. **Phase / current (baignade).** The phase band `0.4...0.6` is intersected over the interval. An extremum inside the interval makes the phase wrap, so the band is intersected; a nominal phase outside the band but an interval that crosses it → `.insufficientMargin`; an uncomputable phase → `.dataUnavailable`. **The gate requires the national (Brest) coefficient**; while `TideState.coefficientSource` is `.localProxy`, baignade is `.dataUnavailable` (Z18).
4. **Daylight.** Both interval endpoints must be daylight; a dawn/dusk crossing blocks.
5. **Coverage (Z15).** If the samples do not cover the whole interval — in particular around local midnight — the helper returns `nil` and the sample is `.dataUnavailable`; never an implicit « no risk ». The engine builds a safety curve over the local day **± 2 h** so a normal 45–70 min envelope is always covered; a larger envelope degrades to `.dataUnavailable`.
6. **Horizon (Z16).** The validity horizon is checked at **`t + u_t`**, not at `t`: the last envelope before `validUntil` is `.dataUnavailable`, never a silent prediction past the horizon.
7. **Slot.** A slot is `go` only when **every** sample in it is unblocked after steps 1–6. A blocked sample breaks the run, as in the M1 window scanner.
8. **Reason.** A threshold straddled by the bound yields `Non` with **« Marge insuffisante »**; the UI never shows `Oui` when the envelope is not fully clear.
9. **UI.** The spot detail shows the model label and the bound: « modèle local — station 190 · ±70 min / ±0.70 m »; station 15 shows « modèle local — station 15 · ±75 min / ±0.60 m ». The coefficient is not displayed in v1 (Z23).

**Implementation and tests (M1).** `TideState.minimumHeight`, `maximumHeight`, `maximumMinutesFromNearestEvent`, `phaseIntersects` and `coversInterval` implement steps 1–6, with `RuleSignals.isBeyondValidityHorizon` for the horizon. `UncertaintyGateTests` covers a low water inside the envelope (boating), a low water pushed out of the 2-hour gate (pêche à pied), a phase-band crossing (baignade) and the no-envelope nominal path. `HorizonAndCoverageTests` covers 23:55 / 00:05 coverage, an uncovered interval, the horizon at `t + u_t`, and the local-proxy coefficient. The tests assert the verdict and the reason, not only the happy path.

**What the bound is not:** a promise of accuracy, or a licence to show `Oui` at the edge. `u_t` and `u_h` are measured one-sided bounds; widening one only removes `Oui`.

### 7.4 What the app must never say

- « Mesure locale » — the app never measures; it evaluates a model.
- « Marée officielle », « prédiction SHOM », « données validées par le Shom », « données officielles ».
- A single accuracy number for all spots.
- « Estimation — modèle local » in v1: no estimated spot ships.
- A « Oui » at a spot whose envelope is not fully clear.
- A « Oui » past the model's `validUntil` horizon.
- A « Oui » on a spring-current verdict derived from the local coefficient proxy.

`Spot.modelLabel` is tested against « mesure locale », « officielle » and « SHOM » (`TideModelLoaderTests`).

---

## 8. Currents at the passes — negative finding

**Fact** — the free Gascogne 2D atlas is: 2 km grid, 30 min steps, **surface** currents only, **two tide conditions (coefficients 45 and 95)**, time relative to **high water at Concarneau**, −6 h to +6 h, netCDF-CF, **Licence Ouverte 2.0**.

**Inference:** it cannot validate the pass-current gate.

- The Arcachon inlet is ~1–2 km wide with channels of a few hundred metres; a 2 km grid cannot resolve them.
- Two coefficients and 30-min steps cannot support a phase band of 0.4–0.6 at an arbitrary coefficient.
- Time relative to Concarneau HW needs a station-specific conversion the product does not provide for Arcachon.

**Decision:** the gate stays a **documented conservative heuristic** — coefficient ≥ 100 and phase 0.4–0.6 → `.strongCurrent`; unknown phase → `.dataUnavailable` — explicitly labelled **unvalidated**. The atlas is not used. A real validation requires an in-situ campaign or a bespoke SHOM study, both out of budget.

**Dependency:** the coefficient fix (§4.6) must land before this gate can be trusted, because the threshold is a national coefficient, not a local ratio.

---

## 9. Refresh pipeline

| Step | Command / artefact | Frequency |
|---|---|---|
| Download station list + metadata | `scripts/tides/refresh --stations` | each run |
| Download observations (31-day chunks / async) | `scripts/tides/refresh --download` | each run |
| QC + fit + validate | `scripts/tides/refresh --build` | each run |
| Write dataset | `EstranCore/Resources/tide-model-<year>.<revision>.json` | each successful run |
| Accuracy report | `docs/data-sourcing/accuracy-<year>.md` | each run |
| App release | embed the dataset, update the attribution date | annual |

**Rules:**

- No network at runtime. The app, widgets and Live Activity read the embedded JSON only.
- A failed validation blocks the dataset write and the merge.
- A failed download does not delete the previous dataset; the app keeps the last valid one.
- The annual refresh is a quality improvement, not a legal requirement: the licence has no expiry.
- The dataset records `retrievedAt` and `sourceLastUpdate`; the attribution string uses `sourceLastUpdate`, not the build date.
- Every run writes `validUntil` (fit end + 3 years) and `nodalCorrections: false`; the loader rejects a dataset without a horizon or with nodal corrections enabled.
- Every run writes `accuracy.extrema.*.maxHeightMeters` and `maxMinutes`; a p95-only report is rejected.
- Every spot writes `correctionStatus`, `validation` and `uncertainty.basis`; `lag 0 / amp 1.0` without `correctionStatus` is rejected.
- The generated JSON is loaded by `TideModelLoaderTests` (JSON → `TidalStation` → `TideEngine` → known date) in CI; no manual patching.
- The QC report is written next to the dataset and lists every rejected station-year with the failed check.

---

## 10. Open questions and blockers

| # | Question | Owner | Status |
|---|---|---|---|
| 1 | **D3 — v1 coverage** | **Anthony** | **Revised — Option A** (2026-10-27): v1 ships 2 gauged spots; the 12 estimated spots are post-v1. |
| 2 | **D2 — bound-based accuracy target** (§6.4) | Architect | **Settled:** median ≤ 10 min, p95 ≤ 30 min, max ≤ 45 min, RMSE ≤ 0.20 m, `\|bias\|` ≤ 0.05 m, p95 `\|Δh\|` ≤ 0.40 m; max `\|Δh\|` required at release. |
| 3 | Coefficient fix (§4.6) and Brest model | Lead | **Model fitted, validation missing.** Station 3 ships in the dataset with `role: coefficientReference` (RMSE 0.1476 m), but it is not validated against a published Annuaire sample. The spring-current gate therefore stays `.dataUnavailable` (Z18). |
| 4 | `ConstituentSpeeds` extension (`MN4`, `2Q1`, `RHO1`, `M1`) | Lead | **Closed** — 25 symbols, 100 tests pass. |
| 5 | Nodal corrections | Lead | **Deferred with a hard horizon:** `nodalCorrections: false`, `validUntil` required, `TideEngine` fails closed past it. |
| 6 | Calm-weather flag source and thresholds | Lead | Proposed (Open-Meteo historical); not verified. |
| 7 | Calibration of the lag/amplitude corrections | Architect + Lead | **Stopped for v1** (D3 = A). Deferred to the post-v1 catalog; no value is invented. |
| 8 | `zh_ref` for stations 6327/150/191 | Lead | Not verified. |
| 9 | Max `\|Δh\|` at extrema | Lead | **Measured: 0.9431 m at 190, 0.7814 m at 15, 0.7493 m at 3** (2025-01-28 storm surge at 190). Published in the dataset as `accuracy.maxHeightMeters`. |
| 10 | macOS/Xcode gates (`xcodebuild`, SwiftLint `--strict`, entitlements, CI) | Lead | **Pending** — no Apple host. |
| 11 | Per-station time bound at 190 (Z19) | Architect | **Decided:** `u_t = 70 min` (SHOM 2025 max 57.8 min + margin). Pêche à pied stays active; its `Oui` window narrows to ≈ 50 min. Measured max 47.8 min → the envelope holds. |
| 12 | **`u_h` one-sided bound (Z21/Z27)** | **Architect** | **Closed.** `u_h = LOYO max(pred − obs) + 0.05 = 0.70 m` (190) / `0.60 m` (15). The dataset publishes `maxUnderPredictionMeters`, `minOverPredictionMeters` and the LOYO table; `maxAbsoluteErrorMeters` is information only. |
| 13 | `u_t(15) = 45 min` vs measured 44.2 min | Lead | **Thin margin (0.8 min).** Widen to 50 min at the next dataset revision. |

---

## Appendix A — SHOM paid products (hors budget — non recommandé)

Kept as a factual reference only. **Nothing in this appendix is part of the M1 route.**

### A.1 Licence

- **Free app, indirect advantage:** Annexe 7 of the RIP 2026 permits smartphone apps (art. 3.1); attribution and reproduction authorisation number required (art. 8.1).
- **Paid app / subscription / tide-dependent premium:** excluded by art. 4; requires a negotiated contract with a **35 %** royalty (`R = P × T × D × V`, T = 35 %), semi-annual declarations and audit rights.
- **Term:** rights granted for the subscribed duration; on termination the licensee must « cesser immédiatement toute utilisation » (art. 11).

### A.2 Products and prices

| Product | Price HT | Notes |
|---|---|---|
| Marées à la carte (SUP Marée) | from **65,74 €/unit** | HW/LW + heights at 1/5/10/15/30/60 min; TXT/XML |
| Marées à la carte — abonnement | **4 601,94 €** (Répertoire) / **4 601.74 €** (product page) | API key; 0.20 € discrepancy flagged |
| Prédictions en tout point (SAPM) | from **230,10 €/unit** | Model-based, not observation-calibrated; excludes catalogue ports and some inner seas |
| Harmonic constants | **not found** | No catalogue line; bespoke quote via `bp@shom.fr` |
| Atlas courants 2D Gascogne | **0 €** | 2 km / 30 min / coef 45–95; Licence Ouverte 2.0 |
| Ouvrage 565 — courants Gascogne | **33,75 €** | PDF only; not machine-readable |

### A.3 Horizon

- Official predictions: **current year + following year** only.
- Multi-year path: up to **20 years (7305 days)** per order, but **not official** beyond N+1.
- Legal time: restricted to official years. Multi-year orders use **UTC or local time**.
- Height series in a legal-time order are returned in **UTC+01:00 even in summer** (ingestion pitfall).

### A.4 Why it is not used

The 0 € constraint forbids it. The free route is technically credible and already measured (§6). If a budget appears later, the v2 analysis remains valid as a purchasing reference; it is not a prerequisite for M1.

---

## Appendix B — Sources

All accessed 2026-10-26 unless stated.

- **[L1]** data.gouv.fr — REFMAR RONIM dataset, licence `lov2`: https://www.data.gouv.fr/datasets/reseaux-de-reference-des-observations-maregraphiques-refmar-maregraphes-ronim
- **[L2]** data.gouv.fr — REFMAR partenaires dataset, licence `lov2`: https://www.data.gouv.fr/datasets/reseaux-de-reference-des-observations-maregraphiques-refmar-maregraphes-partenaires
- **[L3]** Licence Ouverte 2.0 text: https://github.com/etalab/licence-ouverte/blob/master/LO.md
- **[R1]** REFMAR service page (31-day limit, async endpoint): https://services.data.shom.fr/support/fr/services/refmar
- **[R2]** Station inventory (176 stations): `GET https://services.data.shom.fr/maregraphie/service/tidegauges/`
- **[R3]** Station metadata: `GET https://services.data.shom.fr/maregraphie/service/completetidegauge/{id}` (15, 190, 297, 3)
- **[R4]** Observation download: `POST https://services.data.shom.fr/maregraphie/dl/observations` (`type` `txt`/`json`; `CSV` → 400)
- **[S1]** RIP 2026 (Annexe 7, art. 3.1/3.2/4/6.1/7/8.1/11): https://diffusion.shom.fr/media/wysiwyg/licence/Document_RIP_2026-VF.pdf
- **[S2]** Répertoire 2026 (prices): https://diffusion.shom.fr/media/R_pertoire-2026.pdf
- **[S3]** SUP Marée notice (official years, 20-year path, legal-time restriction, UTC+01:00 heights): https://services.data.shom.fr/static/specifications/notice_marees_a_la_carte.pdf
- **[S4]** SAPM product page (230,10 €, model-based, coverage exclusions): https://diffusion.shom.fr/marees/calcul-avance/maree-en-tout-point.html
- **[S5]** Gascogne 2D atlas (2 km, 30 min, coef 45/95, Licence Ouverte 2.0): https://diffusion.shom.fr/marees/courants-de-maree/atlas-de-courants-de-maree-2d-gascogne.html
- **[S6]** Public WFS port list (439 records): `SPM_PORTS_WFS:liste_ports_spm_h2m`, key `<WFS_KEY>`, `Referer: https://maree.shom.fr/` required. No key committed.
- **[C1]** Coefficient de marée definition (Brest, U = 6.10 m): https://fr.wikipedia.org/wiki/Coefficient_de_mar%C3%A9e
- **[Repo]** `ARCHITECTURE_PLAN.md` §8/§8.1/§18, `DESIGN_REFERENCE.md` §4, `worksplit.md` M1.
