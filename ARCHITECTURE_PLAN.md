# Estran — Architecture Plan

> Native iOS app in SwiftUI for the Bassin d'Arcachon and the Médoc.
> Answers, in one second, the question **« C'est un bon moment pour sortir ? »** with **Oui / Non**, based on the chosen activity and spot.

| | |
|---|---|
| **Project** | Estran (working title) |
| **Client / Owner** | Forge Digitale Solutions — Anthony Marcelin |
| **Platform** | iOS 27+ (native, SwiftUI) |
| **Language** | Swift 6 (strict concurrency) |
| **Backend** | None — 100% on-device |
| **UI language** | French (short copy, tutoiement) |
| **Status** | Draft v1 — pending Figma mockups & spot list |
| **Author** | Principal Architect (this agent) |

> **Language note (Forge Digitale convention):** this document is *internal technical documentation* and is written in English, like commits, branches and PRs. Anything the end user reads (UI strings, generated texts, notifications) is French.

---

## 1. Vision & goals

Estran cross-references **tides** (times, heights, coefficient), **wind**, **swell** and **weather**, and turns them into a single, immediate answer: **Oui** or **Non** — with a short reason and the next good time window.

The product promise is speed and trust: the user never opens three apps and does the math themselves. Estran does it and, via widgets, Live Activity and Siri, the answer is visible **without even opening the app**.

### 1.1 Non-negotiable constraints

1. **100% on-device, no backend.** All forecasts and predictions are fetched directly from the data providers or computed locally. Favorites and settings are local.
2. **Weather & wind → Apple WeatherKit.**
3. **Swell → Open-Meteo Marine API** (free, keyless).
4. **Tides → computed locally** (harmonic model) or embedded. No runtime tide API dependency.
5. **Short texts generated on-device** by Apple Intelligence (Foundation Models framework), with a deterministic fallback.
6. **Siri** via App Intents (`« C'est bon pour sortir ? »`).
7. **Local notifications** scheduled for good windows.
8. **Widgets, Live Activity, Dynamic Island** surface the answer without launching the app.
9. Favorites stored locally.

### 1.2 Activities (the 5)

| Activity | French label | Key signals |
|---|---|---|
| Pêche à pied | Pêche à pied | Low tide timing, coefficient, wind, rain |
| Surf | Surf | Swell height/period/direction, wind (offshore), tide phase |
| Bateau | Bateau | Wind, swell, water depth (tide), visibility |
| Balade | Balade | Rain, wind, temperature, low tide bonus |
| Baignade | Baignade | Water & air temperature, wind, swell, current (tide) |

### 1.3 Key screens

1. **Home** — big Oui/Non for *now*, short reason, next good window, 4 tiles (marée, vent, houle, météo), Apple Intelligence tip.
2. **Spot detail** — today's tide curve (with good-window band), conditions, per-activity slots, 1h-before alert toggle.
3. **Activity picker** — the 5 activities, each with its own Oui/Non and representative spot.
4. **Widgets / Live Activity / Dynamic Island** — the answer without opening the app.

**Navigation** (Liquid Glass tab bar, 4 tabs): `Maintenant` · `Spots` · `Alertes` · `Réglages`. Favorites are a per-spot heart toggle (spot detail), not a tab.

---

## 2. Architecture overview

```
                        ┌─────────────────────────────────────────────────┐
                        │                PRESENTATION (App)               │
                        │   SwiftUI · Liquid Glass · @Observable VMs      │
                        │   Features: Home / Spot / Activity / Favorites  │
                        └───────────────▲─────────────────▲───────────────┘
                                        │                 │
                    ┌───────────────────┴───┐      ┌──────┴────────────────┐
                    │   Widgets / Live Act. │      │   AppIntents / Siri    │
                    │   (WidgetKit, Activity)│      │   Notifications       │
                    └───────────▲───────────┘      └──────▲────────────────┘
                                │                          │
                        ┌───────┴──────────────────────────┴────────┐
                        │         EstranCore (local SPM)             │
                        │  ┌───────────┐  ┌──────────────────────┐   │
                        │  │  Domain   │  │  DecisionEngine      │   │
                        │  │  Models   │  │  (rules per activity)│   │
                        │  └───────────┘  └──────────────────────┘   │
                        │  ┌───────────┐  ┌──────────────────────┐   │
                        │  │  Tides    │  │  TextGeneration      │   │
                        │  │  (harmonic)│  │  (FoundationModels + │  │
                        │  └───────────┘  │   fallback templates) │  │
                        │                 └──────────────────────┘   │
                        │  ┌──────────────────────────────────────┐   │
                        │  │  Data: WeatherKit · Open-Meteo       │   │
                        │  │        SpotsCatalog · SwiftData      │   │
                        │  └──────────────────────────────────────┘   │
                        └─────────────────────────────────────────────┘
```

**Key structural decision:** all reusable logic (models, decision engine, tide engine, text generation, data services) lives in a **local Swift Package `EstranCore`**, imported by two Xcode product targets:

- **Estran** (app)
- **EstranWidgets** (widget + Live Activity extension)

A future watchOS/iPadOS target may be added later without changing this package.

This guarantees the decision logic is computed identically inside the app, the widget timeline, and the Live Activity — no duplication, no drift.

---

## 3. Technology stack & key decisions

| Concern | Choice | Rationale / alternatives considered |
|---|---|---|
| UI framework | **SwiftUI**, iOS 27 APIs | Native requirement. Liquid Glass (`glassEffect`, `.buttonStyle(.glass)`, glass background effects), new `Tab` API, `scrollTargetBehavior`. |
| Language / concurrency | **Swift 6**, strict concurrency, async/await, actors, `Sendable` | Modern default; data services are actors. |
| State management | **Observation** (`@Observable`, `@Environment`, `@Bindable`) | Replaces ObservableObject/Combine for new code; iOS 17+. |
| Persistence | **SwiftData** | Favorites, cached forecasts/tides, settings. Mature enough on iOS 27. Core Data only if model migrations demand it. |
| Weather & wind | **Apple WeatherKit** | Required by spec. Needs an Apple Developer entitlement (note: usage metering applies beyond free tier). |
| Swell / waves | **Open-Meteo Marine API** | Free, keyless, returns wave height/period/direction + sea surface temperature. Fetched with `URLSession`, cached locally. |
| Tides | **Local harmonic model** + constants derived from **REFMAR observations** (Licence Ouverte 2.0) | Zero-budget route: free observations → build-time harmonic analysis → embedded constants. No runtime tide API. The model is an estimation, not a SHOM-official prediction. SHOM tables/constants are an optional future route. |
| Text generation | **Foundation Models framework** (on-device, Apple Intelligence) | Generates the short reason. Mandatory deterministic **template fallback** (simulator, no Apple Intelligence, API unavailable). |
| Siri | **App Intents** (`AppIntents`), `AppShortcut` phrases | `« C'est bon pour sortir ? »`. |
| Notifications | **UserNotifications** (local, scheduled) | Good-window alerts; 1h-before alerts. |
| Glanceable answers | **WidgetKit** + **ActivityKit** (Live Activity + Dynamic Island) | Answer without opening the app. |
| Location | **Core Location** | Nearest-spot default; user location is optional and never leaves the device. |
| Networking | `URLSession` + `async/await`, JSON `Codable` | Single lightweight client for Open-Meteo. |
| Background refresh | **BGTaskScheduler** | Keep widget/Live Activity data fresh without a backend push. |

---

## 4. Repository & target layout

```
entrant/
├── ARCHITECTURE_PLAN.md
├── worksplit.md                     # file ownership between agents (created with Kimi)
├── Estran/                          # APP target (presentation only)
│   ├── App/
│   │   ├── EstranApp.swift
│   │   ├── RootView.swift
│   │   ├── AppIntents/
│   │   │   ├── CheckConditionsIntent.swift
│   │   │   ├── SpotEntity.swift
│   │   │   ├── ActivityEntity.swift
│   │   │   └── EstranShortcuts.swift
│   │   └── Background/              # BGTask scheduling, notification scheduling
│   ├── Features/
│   │   ├── Home/                    # HomeView, GoBadge, ConditionTiles, HomeViewModel
│   │   ├── SpotDetail/              # SpotDetailView, TideChartView, ActivitySlotsView, VM
│   │   ├── ActivityPicker/          # ActivityPickerView, VM
│   │   ├── Favorites/
│   │   ├── Settings/
│   │   └── Onboarding/
│   ├── Theme/                       # OceanPalette, Typography, GlassStyles, Spacing
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Localizable.xcstrings    # French strings
│   └── Info.plist / entitlements
├── EstranWidgets/                   # WIDGET + LIVE ACTIVITY extension
│   ├── GoWidget.swift
│   ├── ConditionsWidget.swift
│   ├── LiveActivity/
│   │   ├── GoActivityAttributes.swift
│   │   └── GoLiveActivityView.swift
│   └── TimelineProviders/
├── Packages/
│   └── EstranCore/                  # LOCAL SWIFT PACKAGE (shared logic)
│       ├── Package.swift
│       ├── Sources/EstranCore/
│       │   ├── Models/
│       │   ├── Domain/
│       │   │   ├── DecisionEngine/
│       │   │   ├── Tides/
│       │   │   └── TextGeneration/
│       │   ├── Data/
│       │   │   ├── Weather/
│       │   │   ├── Marine/
│       │   │   ├── Spots/
│       │   │   └── Persistence/
│       │   └── Resources/           # embedded harmonic constants (JSON)
│       └── Tests/EstranCoreTests/
├── EstranTests/
├── EstranUITests/
└── project.yml or .xcodeproj        # see §16 tooling
```

### 4.1 Target membership (shared code)

- `EstranCore` → `@testable import` by unit tests; imported by app + widget targets.
- Widget/Live Activity bundle must be in the same App Group as the app to read/write shared cache and user defaults (`group.com.forgedigitalesolutions.estran`).

---

## 5. Data models (EstranCore/Models)

All models are `Sendable`, `Codable`, `Equatable`, and hashable where used as AppIntents entities.

```swift
enum Activity: String, Codable, CaseIterable, Identifiable, Sendable {
    case shoreFishing   // Pêche à pied
    case surfing        // Surf
    case boating        // Bateau
    case walking        // Balade
    case swimming       // Baignade
    // French display name, SF Symbol, tint color
}

struct Spot: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String            // "Cap Ferret", "Lacanau"…
    let region: Region          // .bassin, .medoc
    let coordinate: Coordinate  // lat/lon
    let tideStation: TideStationRef
    let supportedActivities: Set<Activity>
    let timezone: TimeZone
}

struct TideEvent: Codable, Hashable, Sendable {
    let time: Date
    let kind: Kind              // .high, .low
    let height: Double          // meters
}

struct TideState: Sendable {
    let current: TideEvent?         // last event before now
    let next: TideEvent?            // next event after now
    let coefficient: Int            // 20…120 (French marée coefficient)
    let curve: [TidePoint]          // samples for the day chart
}

struct Wind: Sendable { let speed, gust, directionDegrees: Double }

struct Swell: Sendable {
    let waveHeight, period, directionDegrees: Double
    let seaSurfaceTemperature: Double?   // °C, for Baignade
}

struct WeatherNow: Sendable {
    let temperature: Double
    let condition: WeatherCondition
    let precipitationChance: Double      // 0…1
    let cloudCover: Double               // 0…1
    let wind: Wind
    let visibility: Double
}

struct Conditions: Sendable {
    let spot: Spot
    let at: Date
    let tide: TideState
    let weather: WeatherNow
    let swell: Swell
}

struct GoDecision: Sendable {
    let activity: Activity
    let spot: Spot
    let go: Bool                        // Oui / Non
    let score: Double                   // 0…1 (pre-threshold)
    let reason: String                  // short FR text (generated or fallback)
    let reasonSource: ReasonSource      // .foundationModel, .template
    let nextGoodWindow: DateInterval?   // next good slot
    let computedAt: Date
}

struct ActivitySlot: Identifiable, Sendable {
    let activity: Activity
    let window: DateInterval
    let score: Double
    let go: Bool
}
```

### 5.1 SwiftData persistence models (separate from domain models)

- `FavoriteSpot` (`@Model`) — spot id + chosen activities + alert preference.
- `CachedForecast` (`@Model`) — spot, fetchedAt, JSON payload of `Conditions`/forecast series, TTL.
- `CachedTide` (`@Model`) — station, day, JSON of `TideState` (or computed on the fly; caching is optional since computation is cheap).
- `AppSettings` — default spot, default activity, notification preferences.

> Domain models stay plain structs; SwiftData `@Model` types are a thin persistence layer so the widget/app can share the same `EstranCore` domain without coupling to SwiftData in the widget (where not needed).

---

## 6. State management & concurrency

- **`@Observable` view models**, `@MainActor`, one per feature. Injected via `.environment()`.
- A single **`ConditionsStore`** (`@Observable`, `@MainActor`) aggregates the current `Conditions` + `GoDecision` for the selected spot/activity and publishes changes to all features.
- **Services are `actor`s** (`WeatherKitService`, `MarineService`, `TideEngine`, `DecisionEngine`), all `Sendable`, called with `await` from the store.
- Data flow is **unidirectional**: Services (async) → Store (@MainActor, state) → Views (read-only) → user actions → Store.
- No shared mutable global state outside the store; user defaults + SwiftData for persistence.
- The widget/Live Activity read a **serialized snapshot** (`GoDecision` + `Conditions`) from shared storage (App Group), refreshed by the app's background task, so the widget never calls the network itself.

---

## 7. Domain — Decision Engine (`EstranCore/Domain/DecisionEngine`)

Rule-based scoring, deterministic and testable. Each activity has a rule set producing a **score in 0…1** and a **go threshold**.

```swift
protocol ActivityRule: Sendable {
    var activity: Activity { get }
    func score(_ c: Conditions) -> Double           // 0…1
    var threshold: Double { get }                   // score >= threshold → Oui
    func blockers(_ c: Conditions) -> [ActivityBlocker] // hard Non signals
    func nextGoodWindow(from conditions: [Conditions]) -> DateInterval?
}

extension ActivityRule {
    // Oui only when no blocker fires and the score reaches the threshold.
    func isGo(_ c: Conditions) -> Bool {
        blockers(c).isEmpty && score(c) >= threshold
    }
}

struct DecisionEngine: Sendable {
    func decide(activity: Activity, conditions: Conditions) -> GoDecision
    func windows(activity: Activity, over forecast: [Conditions]) -> [ActivitySlot]
}
```

### 7.1 Per-activity rules (baseline — to be tuned against real data)

| Activity | Go when… | Blockers |
|---|---|---|
| **Pêche à pied** | Coefficient ≥ 70, within ±2h of low water, wind < 15 km/h, no rain | Rain, wind ≥ 30 km/h, coefficient < 50 |
| **Surf** | Wave 0.8–2.5 m, period 8–14 s, favorable direction, offshore/light wind (< 20 km/h), rising or falling tide | Storm, onshore strong wind, waves < 0.5 m |
| **Bateau** | Wind 5–20 km/h, swell < 1 m, sufficient water (not extreme low spring), visibility good | Wind ≥ 25 km/h, swell ≥ 1.5 m, fog/storm |
| **Balade** | No heavy rain, wind < 30 km/h, 8–30 °C | Rain ≥ 60% chance, wind ≥ 40 km/h |
| **Baignade** (advisory, §7.3) | Water ≥ 18 °C, air ≥ 20 °C, wind < 20 km/h, swell < 0.8 m, daylight, not during strong pass current | Water < 18 °C, air < 20 °C, wind ≥ 20 km/h, swell ≥ 0.8 m, night, strong or unknown pass current, storm |

Each rule is a small, pure, independently unit-tested type. Weights per signal are the tunable part and will be calibrated in M1 with reference scenarios.

**Safety gates.** The safety-critical "Go when…" conditions above are hard gates for pêche à pied, surf, bateau and baignade; balade uses comfort gates. Non-safety preferences (e.g. surf at slack tide) remain scored signals. The weighted score may rank windows but cannot turn a failed safety gate into `Oui`. A missing safety-critical signal (water temperature, water height, low-water event, or a strong-current check that cannot be evaluated) is a blocker, never a neutral score. `Spot.minimumWaterHeight == nil` means the rule's conservative default (0.5 m) applies; it is not neutral.

**Pass-current model (baignade) — local range, not the national coefficient.** The gate is a function of each spot's **predicted daily tidal range** and the tide phase. Every spot carries `swimmingRange { lowBelow, strongAt }`, calibrated in the generator: `T` is the local range reached on the same number of days as a national coefficient ≥ 100 (37 days, ~10 % of 2025), with a ±0.30 m uncertainty band — 190: `T` 3.88 → 3.58 / 4.18; 15: `T` 4.335 → 4.03 / 4.63. Levels: `strong` when range ≥ `strongAt` **and** phase in `0.4...0.6` (mid-tide, not slack); `moderate` when range ≥ `lowBelow` whatever the phase — the grey band, so the app never says « faibles » on a range it cannot classify; `low` otherwise. A missing range, phase or calibration is `unknown` (`.currentDataUnavailable`), never « faibles ». The national coefficient is no longer an input: it stays computed, unvalidated and unshown. Measured distribution on 2025: Arcachon 80 % low / 16 % moderate / 4 % strong-eligible, Pointe de Grave 82 / 13 / 5, and « strong » only holds for the mid-tide hours of those days. **Whatever the gate computes, its output is an advisory level only — never `Oui` (§7.3).**

### 7.2 "Next good window"
Scan the forecast horizon (48h) forward, using predicted `Conditions`; a window is a contiguous run of ≥ 1h where `isGo` is true (no blocker **and** `score ≥ threshold`). A blocked sample breaks the window; a slot is `go` only when every sample in it is unblocked. Return the earliest window starting after now. This is a pure function over `[Conditions]` and therefore unit-testable. `WindowScanner` infers the sampling step (30-min or hourly); `ConditionsProvider` may pass either series but must keep a regular step.

### 7.3 Baignade is advisory — never a green light

Anthony, 2026-10-27: *« Il faudra qu'on soit très prudent avec la baignade… C'est très, très dangereux là-bas. Il faut vraiment mettre un point d'avertissement pour prévenir les baigneurs. »* This is a product rule, not a copy preference.

**No `Oui` for swimming, anywhere.** The engine may still compute `go/noGo` internally, but every surface — answer card, widget, Live Activity, Siri, Shortcuts — presents baignade as a **risk level**, never as permission:

| Level | Word | Colour |
|---|---|---|
| low | « Courants estimés faibles » | turquoise |
| moderate | « Courants modérés » | sand |
| high | « Courants forts » | coral |

Green (`OceanPalette.oui`) is never used for this activity, and the word « Oui » never appears next to it. The activity chip carries the warning glyph permanently, not only in the unavailable state.

**Permanent warning, always visible**, part of the verdict's accessibility element and of the widget/Siri text. One structure everywhere, one **spot-specific opening line** — the hazard mix differs, the rest does not:

- **Arcachon (bassin)** — « Toute l'année, dans le bassin, les baïnes et les courants de marée sont dangereux, même par temps calme. Reste dans une zone surveillée, jamais seul, et garde les enfants à portée de main. »
- **Pointe de Grave (océan)** — « Toute l'année, sur l'océan, les baïnes créent des courants de retour dangereux, même par temps calme. Baigne entre les drapeaux, dans une zone surveillée. »
- **Always, both spots** — « Si un courant t'emporte, ne lutte pas : nage parallèle à la plage. »

And the closing line, which is not negotiable: **« L'app estime les courants de marée. Elle ne voit ni les baïnes, ni les maîtres-nageurs. »** That sentence is what keeps the product honest and what an App Review reviewer will look for under guideline 1.4.1.

**Baïnes are not an ocean-only phenomenon and must not be presented as one.** Anthony corrected this on 2026-10-27: they are a hazard *in* the Bassin too, not just on the open coast. The warning names them at both spots; the opening line only changes the mechanism (tidal currents in the passes vs rip currents on the ocean shore).

**Year-round, no seasonal framing.** Anthony, 2026-10-27: *« Été comme hiver, printemps et automne, faut faire attention aux baïnes. »* Nothing in the UI may imply that the off-season is safer, that the warning applies « en été », or that the lifeguard season defines the danger. « Toute l'année » is part of the copy, not an implication.

**Visual hierarchy: the warning leads, the level follows.** For Anthony the product *is* the warning; the current level is a secondary fact (« courants de marée estimés : faibles »). The card therefore reads **title → warning → conditions → level**, never level first. A big « Courants estimés faibles » above the hazard would say the opposite of what the activity exists for. Same order in the widget and the Live Activity, where the level may shrink to a word but the baïnes never disappear.

**What the app does not know, and must never imply:** the presence of baïnes (beach morphology, not tide), water quality, lifeguard hours and zones, the bather's ability, or what happens 200 m from the spot. A calm verdict is an estimate of tidal current, not a safety certification.

Consequence for the gate: the input is the **local predicted range** (§7.1), and it only chooses the **level**. It can never re-enable a binary `Oui`.

---

## 8. Domain — Tide engine (`EstranCore/Domain/Tides`)

- **Harmonic model**: standard sum of constituents `h(t) = Z0 + Σ H_i · cos(ω_i·t − g_i)`. The constants are **derived at build time from REFMAR observations** (zero-budget route). SHOM's own constants are not a catalogue product and would require a bespoke quote; they are an optional future route, not the M1 route.
- **Bassin d'Arcachon specifics**: the Bassin is a semi-enclosed lagoon; tides are delayed and damped relative to the open Atlantic. `ARCACHON_EYRAC` (REFMAR station 190) is the only gauge in the Bassin. Cap Ferret is 7 km away; the interior spots (Andernos, Arès, Gujan-Mestras) have **no gauge** and no SHOM rattachement site. Using `ARCACHON_EYRAC` plus a local lag is a modelling assumption, not a validated prediction — which is why **v1 ships Arcachon-Eyrac only** (D3 = A) and the interior spots are deferred until a correction is validated. M1 accuracy target at the gauged stations, measured against **held-out REFMAR observations**: median `|Δt|` ≤ 10 min, p95 ≤ 30 min, max ≤ 45 min, RMSE ≤ 0.20 m, `|bias|` ≤ 0.05 m, p95 `|Δh|` ≤ 0.40 m. The old ±15 min/±15 cm target is withdrawn; no accuracy claim is made at ungauged spots.
- **Coefficient de marée (20…120)**: the French coefficient is defined at **Brest**: `C = round((H_h − H_b) / 6.10 × 100)`, clamped 20…120. The current engine's local `range / meanSpringRange` formula is a known defect (D4); until the Brest model ships, the UI labels the value « coefficient local estimé », not « coefficient de marée ». Validate against a manual sample of the Annuaire (no scraping); SHOM coefficient tables are optional.
- **Validity horizon**: the baseline engine has no nodal corrections. If the dataset declares `nodalCorrections: false`, it must carry a `validUntil` (fit end + 3 years) and `TideEngine` must fail closed past it. Do not predict beyond the horizon silently.
- **Tide curve**: sample the model every 10–15 min over the day for the spot's chart.
- **`TideEngine`** is an `actor` producing `TideState` for `(station, date)`.

> **Data route decision (0 €).** The primary route is **REFMAR observations → local harmonic analysis → embedded constants**, with attribution « Source : REFMAR / Shom — Licence Ouverte 2.0 ». SHOM prediction tables are an optional future route if a budget appears; they are not the M1 route. The derived model is **not** a SHOM-official prediction: the UI says « estimation » / « modèle local », never « données officielles ».

### 8.1 Data sourcing and refresh (zero-budget route)

- **Acquisition is build-time, never runtime.** REFMAR observations are downloaded during development or release preparation; the derived constants are embedded in `EstranCore/Resources`. The app, widgets and Live Activity never call a tide API (M2 checklist).
- **Primary source (0 €): REFMAR / RONIM observations under Licence Ouverte 2.0.** Free API at `ARCACHON_EYRAC` (station **190**, RONIM, OK), `PORT-BLOC` / `PORT_BLOC_GPM` (stations **15** and **297**, Pointe de Grave; 15 is KO but has validated historical data, 297 is OK but only raw source 1) and `BREST` (station **3**, RONIM, OK) for the national coefficient. The working endpoint is `GET https://services.data.shom.fr/maregraphie/observation/json/{id}?sources={n}&dtStart=YYYY-MM-DD&dtEnd=YYYY-MM-DD` — the format sits **before** the id (`/observation/190` returns 404). `sources`: 4 = validated hourly (fit input), 3 = validated 10-min (extrema QC), 1 = raw 1-min (QC only). **Four traps, verified 2026-10-27**: (1) the **31-day limit is silent** (a longer range returns HTTP 200 truncated to 31 days); (2) **`dtEnd` is inclusive of the closing midnight and exclusive of that day** — `dtStart=2025-01-01&dtEnd=2025-01-31` returns 721 rows ending `2025/01/31 00:00`, so a naive `cursor + 30 d` chunking loses the 23 h after every window end (288 h per year, invisible to a guard that tolerates 1 h of slack); fetch `dtEnd = span_end` with `cursor = span_end` and assert `len == span_hours`; (3) timestamps are `"YYYY/MM/DD HH:MM:SS"` UTC and not ISO-8601; (4) heights are in the station's `zero_hydrographique` (check `zh_ref` before any comparison). The `/dl/observations` async endpoint and the manual ZIP download are not needed. Download at build time, run a least-squares harmonic analysis, embed the derived constants. The observations are open data; the constants are our own derived dataset.
- **Attribution and licence**: « Source : REFMAR / Shom — Licence Ouverte 2.0 » + retrieval date. The Licence Ouverte allows commercial use, modification and redistribution with attribution. It removes the Annexe 7 / 35 % question. No SHOM prediction table is purchased or embedded.
- **Officiality**: the derived constants are **not** SHOM-official predictions. The UI must say « estimation » / « modèle local », never « données officielles ». The safety gates are conservative and fail closed when the local model is outside its validated range.
- **SHOM prediction tables (optional, not M1)**: if a budget appears later, `PORT-BLOC` and `ARCACHON_EYRAC` N+1 official tables are the reference route; the v2 sourcing report remains the licence/price reference. Multi-year orders can use UTC or a fixed offset (UTC+01:00/UTC+02:00), **not legal time**; the height series in legal time is UTC+01:00 even in summer.
- **Spot coverage (D3 revised — Option A, 2026-10-27)**: the v1 product ships **exactly 2 spots**, the only two with a REFMAR gauge: **Pointe de Grave / Le Verdon** (station 15, QC 297) and **Arcachon-Eyrac** (station 190). Anthony revised D3 from Option B (14 spots, 12 estimated) to **Option A** on 2026-10-27: a verdict is only issued where the model is validated against observations. The **12 estimated spots are out of the v1 catalog** — not shipped, not shown as « bientôt »: Soulac, Montalivet, Hourtin, Carcans, Lacanau, Le Porge, Lège/Crohot, Cap Ferret, Pyla, Andernos, Arès, Gujan-Mestras. They return only when a per-spot correction is validated against independent observations. No `estimatedOpenCoast` / `estimatedLagoon` spot ships in v1; the corresponding enum cases stay in the model for the future catalog but are rejected by the v1 dataset contract. No SAPM (paid) under 0 €.
- **Refresh cadence**: annual re-analysis from the latest REFMAR observations. The observations are free and continuous; no purchase and no licence renewal. The model is deterministic; the annual refresh is a quality improvement, not a legal requirement.
- **Accuracy validation**: train/test split on REFMAR observations (fit 2022–2024, test 2025), in UTC, after verifying the chart datum. Measure extrema timing and height. Proof of concept (2026-10-26): station 190 RMSE 0.175 m, extrema median 7–9 min / p95 22–28 min / max 34–35 min; station 15 RMSE 0.160 m, median 4–6 min / p95 16–20 min / max 29 min. **M1 gate (2026-10-27, per-station consistency rule)**: median `|Δt|` ≤ 12 min, p95 ≤ 35 min, `max |Δt|` ≤ `u_t` − 10 min; RMSE ≤ 0.20 m, `|bias|` ≤ 0.05 m, p95 `|Δh|` ≤ 0.40 m, max under-prediction ≤ `u_h` − 0.05 m. The test year must be measured on the **full** year (no chunking holes), `max under-prediction` over **every year of the record** (leave-one-year-out), and the forward direction (fit 2022–2024 → predict 2026-H1) reported **with its meteorological forcing**: the RMSE target applies to a neutral year, and an anomalous window (2026-H1: January mean pressure 1007.9 hPa, bias −0.078 m) is reported as an anomalous-year measurement, never as model decay over the horizon. No claim of ±15 cm on total water level; no accuracy claim at ungauged spots.
- **Versioning**: every dataset carries `source: REFMAR`, `license: Licence Ouverte 2.0`, `stations`, `spots`, `retrievedAt`, `method`, `constituents`, `nodalCorrections`, `validUntil`, `accuracy`, `official: false` and a checksum (`tide-model-<year>.<revision>.json`). Each spot carries its reference station, `correctionStatus` (`none` / `calibrated` / `estimated`) and its uncertainty envelope.
- **Automation**: a `scripts/tides/refresh` generator downloads the REFMAR series, runs the harmonic analysis, validates against the held-out period and writes the constants JSON; CI runs the accuracy test. A failed test blocks the merge.
- **Currents**: the free 2D Gascogne netCDF atlas cannot resolve the Arcachon inlet/passes (2 km grid, 30 min, coefficients 45/95 only). The pass-current model (coefficient ≥ 100, phase `0.4...0.6`) stays a conservative, unvalidated heuristic; unknown phase → `.dataUnavailable`. Do not claim current validation.
- **Uncertainty bounds (D6, revised 2026-10-27 — one-sided height bound, per-station time bound)**: bounds are derived from each station's own errors, not per class. v1: **station 15** → `u_t = 75 min`, `u_h = 0.60 m`; **station 190** → `u_t = 70 min`, `u_h = 0.70 m`.
  - `u_t` rule: **leave-one-year-out** `max |Δt|` + 10 min allowance, and the larger of the REFMAR hold-out and the SHOM cross-check. 15: LOYO 2023 **64.76** (a flat top within 4 cm for ~100 min, not a double high) and low-water 63.21 → **75**. 190: LOYO 2024 **53.33**, SHOM low-water 57.8 + 12 → **70**. Consequence: the pêche à pied window (`max 120 min from low water`) is ~45 min at Pointe de Grave and ~50 min at Arcachon — accepted, because a wider bound only removes `Oui`.
  - `u_h` rule: **one-sided and leave-one-year-out**. `BoatingRule` is the only consumer and it fails open only when the tide is **over**-predicted, so the bound is `max(pred − obs)` — but over **every year of the record**, not one test year, because the dominant term is interannual atmospheric pressure, not model decay. Measured leave-one-year-out at 190: **0.6059 (2022)**, 0.5577, 0.4910, 0.5032, 0.4741 → `u_h = 0.70`; at 15: **0.5113 (2022)**, 0.4637, 0.3926, 0.4701 → `u_h = 0.60`. The 0.9431 m `max |Δh|` is the positive surge of 2025-01-28, i.e. the *safe* direction; it must not drive the bound. The dataset publishes `maxUnderPredictionMeters`, `minOverPredictionMeters` and the full `leaveOneYearOut` table; `maxAbsoluteErrorMeters` is informational.
  - Measured product cost (tide component only, 0.5 m default draught, 2025): Arcachon **80.8 %** of hours clearable at `u_h = 0.70` (84.5 % at 0.60, 64.2 % at 1.1), Pointe de Grave ≈ 99 %.
- **Validity horizon**: `validUntil` bounds the **astronomical** decay of a harmonic fit — the nodal cycle, ≈ ±1.5 % on M2 from 2025 to 2029, i.e. 0.05–0.07 m, absorbed by `u_h`. It does **not** bound interannual pressure variability: January 2026 ran at 1007.9 hPa against 1027.6 hPa in January 2022, a ≈ 0.20 m sea-level swing present at all three stations and absent in July. That spread is a per-year term, not an accumulating one, so it belongs in `u_h`, never in the horizon. Three-year horizon (2029) plus an annual dataset refresh as a quality ritual, not as a survival condition: after `validUntil` every surface answers `.dataUnavailable`, so an expiry date is a product kill switch.
- **Coefficient**: the national coefficient is defined at Brest with the **conventional 6.10 m divisor**, not the fitted `meanSpringRange` (5.4807 at Brest — using it reads +11 %). The Brest model is fitted but **not validated** (±1 for ≥ 90 % of published coefficients): measured bias +1.75, 37 % within ±1. Consequences: the coefficient is not displayed in v1, the pêche à pied gate moves to the national scale with a +2 margin (`C ≥ 72`), and the dataset carries `coefficientValidated: false` which `SwimmingRule` requires — otherwise fixing the coefficient path would silently enable baignade. Drift over the declared horizon: M2 nodal factor 0.963 (2025) → 0.997 (2029), ±1.5 % around the fit mean, absorbed by `u_h` and the 2-point margin.
- **Text layer**: the reason sentence is written **on device by Apple Intelligence** (Foundation Models framework) — no server, no key, no cost. The model never decides and never states a fact the engine did not compute: it receives a structured `DecisionRationale` and only phrases it. `TemplateReasonProvider` is the deterministic French fallback and must be good enough to ship alone (simulator, non-eligible device, model unavailable, low power). `reasonSource` records which one produced the text.
- **Catalog dependency**: the confirmed **2-spot v1 catalog** (Pointe de Grave, Arcachon-Eyrac) fixes the station mapping; it is an input to the generator, not something the generator can infer. The 12 deferred spots are not part of the v1 generator input.

---

## 9. Data layer (`EstranCore/Data`)

### 9.1 Weather (WeatherKit)

`WeatherKitService` (actor) wraps `WeatherService`, returning current + hourly forecast for `WeatherNow` and a forecast series. Handles authorization and the entitlement requirement. Cached locally with a short TTL (15 min) in `CachedForecast`.

**Fallback.** `FallbackWeatherSource` calls WeatherKit first and Open-Meteo's keyless forecast (`api.open-meteo.com/v1/forecast`: temperature, WMO weather code, precipitation probability, cloud cover, wind speed/gusts/direction, visibility) when WeatherKit cannot answer — a missing capability, an unsigned build or a quota. The substitution is logged; neither source returns a neutral value.

### 9.2 Marine (Open-Meteo)

`MarineService` (actor) calls the Open-Meteo Marine endpoint (`marine-api.open-meteo.com/v1/marine`) with `wave_height, wave_period, wave_direction, sea_surface_temperature`. Maps to `Swell`. Cached with a 30-min TTL.

**The grid is offshore.** Measured 2026-10-28/31: at Pointe de Grave it returns a coherent Atlantic sea (1.16 m / 11.6 s / 278° / 15.7 °C); at the Eyrac jetty, inside the Bassin, it returns the same open-ocean swell (1.4–2.5 m / 11 s) — not the water at the jetty. `MarinePolicy` therefore uses the model at the ocean spot only.

**Inside the Bassin** the sea is a short, fetch-limited wind sea computed from the measured wind (`WindSeaEstimator`, SMB constants, 3 km fetch, `Swell.source = .windSeaEstimate`). It is a model, not a measurement: the UI writes « houle estimée », the sea temperature stays `nil` (« eau indisponible »), and no free source measures the lagoon. See `docs/data-sourcing/marine-2026-10-28.md`.

### 9.3 Spots catalog

`SpotsCatalog` is a static, versioned catalog of `Spot` (id, name, region, coordinates, tide station ref, supported activities). Seeded from JSON in `EstranCore/Resources`. `SpotsRepository` merges the catalog with local favorites/settings.

### 9.4 Forecast pipeline

`ConditionsProvider` (actor) orchestrates the three sources (tide, weather, marine) into `[Conditions]` for the next 48h. It is the single entry point used by the store, the widget timeline and the background refresh.

---

## 10. Intelligence — text generation, Siri, notifications

### 10.1 Short-text generation (Foundation Models)

```swift
protocol ReasonTextProviding: Sendable {
    func reason(for decision: GoDecision) async -> (text: String, source: ReasonSource)
}

struct FoundationModelReasonProvider: ReasonTextProviding { … }  // iOS 26+ Foundation Models
struct TemplateReasonProvider: ReasonTextProviding { … }         // deterministic FR templates
```

- Primary: **Foundation Models framework** (on-device, Apple Intelligence) generates the short reason in French (« Marée basse à 14h20, coefficient 85, vent faible : parfait pour la pêche à pied. »).
- **Deterministic fallback** `TemplateReasonProvider` with curated French sentence templates parameterized by the dominant signal (the engine already knows *why* the score is what it is — it passes a structured `DecisionRationale`). This guarantees the app always shows a correct reason, even on simulator or without Apple Intelligence.
- Generated text is kept **short** (one sentence, ≤ ~120 chars) and **cached** per `(spot, activity, conditions fingerprint)` to avoid regenerating on every render.
- **No device gate, no empty state.** The decision is identical on every device; only the sentence differs. A device without Apple Intelligence (or a model that is not ready, or low power) gets a **complete** template sentence, never a blank, never a degraded layout. Device eligibility is an implementation detail and is never surfaced in the UI.
- **Cost/latency split**: lists (home, activity picker, widgets) use `TemplateReasonProvider` — instant, deterministic, no model call. The **spot detail** and the Siri answer may use the Foundation Model, where one richer sentence is worth the few hundred milliseconds. Never generate five AI sentences for one screen.
- **Output validation** before display: reject and fall back when the model text is empty, over the length budget, contains a number absent from the `DecisionRationale`, or contradicts the verdict (a `Oui`-sounding sentence for a `Non`). The fallback is the safety net, not a visible downgrade.

> M1 ships `DecisionReason` as a deterministic placeholder. From M4, `ReasonTextProviding` is authoritative: `DecisionEngine` must not remain the final text source, and `reasonSource` must reflect the provider that produced the sentence.

> Exact Foundation Models API surface (`FoundationModels` / `LanguageModel`) will be confirmed during M4 against the iOS 27 SDK; the `ReasonTextProviding` abstraction isolates that uncertainty.

### 10.2 Siri (App Intents)

- `CheckConditionsIntent` (`@Intent`) — takes optional `SpotEntity` + `ActivityEntity`, returns the `GoDecision` (Oui/Non + reason + next window) as a dialog.
- `SpotEntity` / `ActivityEntity` conform to `AppEntity` with French display representations.
- `EstranShortcuts` registers an `AppShortcut` with phrases: *« C'est bon pour sortir ? »*, *« Est-ce que je peux aller pêcher à pied ? »*, etc.
- Shortcut answers reuse the **same** `DecisionEngine` and `ReasonTextProviding` as the app (via `EstranCore`), so Siri and the UI never disagree.

### 10.3 Local notifications

- `NotificationScheduler` (UserNotifications) schedules good-window alerts (e.g. "Bon créneau pour le surf dans 1 h à Lacanau").
- Spot detail has a per-activity **"M'alerter 1 h avant"** toggle → schedules a local notification relative to the next good window.
- Notifications are re-scheduled by the background refresh when forecasts change.

---

## 11. Widgets, Live Activity, Dynamic Island

- **Widgets** (`GoWidget`, `ConditionsWidget`) — WidgetKit timeline from the shared `GoDecision` snapshot (App Group). Small/medium sizes. The app's background task refreshes the snapshot; the timeline provider reads it (no network in the widget).
- **Live Activity + Dynamic Island** (`GoActivityAttributes` + `GoLiveActivityView`) — started from the spot detail ("Surveiller ce spot") and/or Siri. Shows Oui/Non + next window, updates via `Activity.update` driven by background refresh (no backend push, per the on-device constraint). Compact/expanded/minimal presentations.
- **App Group** `group.com.forgedigitalesolutions.estran` shared between app and widget for snapshot + settings.

---

## 12. Design system (Theme)

iOS 27 **Liquid Glass**, ocean palette, short French copy with tutoiement.

> **Full design spec** (palette, typography, screens, copy, components, widgets) extracted from the Figma file: see [`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md).

- **Palette** (confirmed from Figma `v3 kit iOS 27`; single dark scheme, see §12.4):
  - Background gradient `#0A3D62 → #031426`
  - Turquoise (accent) `#30D5C8` · Blue glow `#0091FF`
  - Sand `#F2E3C2` · Navy ink `#06223F`
  - **Oui** `#34C759` · **Non (corail)** `#FF6B5B`
  - Glass fill: white + `#BFD9FF` tint
- **Glass**: `glassEffect`, `.buttonStyle(.glass)`, glass background materials for cards/tiles; hairline separators; specular highlight.
- **Typography**: SF Pro / SF Pro Rounded (Figma uses Inter as a placeholder); display numerals for the Oui/Non badge (76pt Home, 48pt widget).
- **Motion**: subtle spring transitions on the Oui/Non badge color flip.
- Components: `GoBadge`, `ConditionTile`, `AnswerCard`, `NextWindowCard`, `TideChart`, `ActivitySegmentedControl`, `ActivitySlotRow`, `SpotButton`, `TabBar`.

### 12.1 Navigation with 2 spots (D3 = A)

The map is a **focus map**, not a browsing map. It opens centred on the selected spot, and switching spots animates the camera between the two — Arcachon-Eyrac and Pointe de Grave — with a spring transition (`MapCameraPosition` + `withAnimation`). The switcher is a floating Liquid Glass control over the map (two glass chips or a segmented control), never a list of pins.

- No empty pins, no « bientôt », no greyed-out spots: the product states **2 places**, clearly and without apology.
- The two spots are far apart (≈ 90 km), so the camera animates between two fixed framings rather than free-zooming; the user never sees an empty stretch of coast.
- Spot identity is carried by the map, the title and the switcher together — the switcher alone is enough at 2 spots, a list would add a tap for nothing.
- The same two-spot model applies to the widget's spot setting and to Siri (`SpotEntity`), so there is exactly one place to choose from in the whole app.

### 12.2 Showcase surfaces (v1)

**Unblocked 2026-10-27**: Anthony has a paid Apple Developer Program membership and a Mac with Xcode. The surface is no longer capped by provisioning, so the boundary is **structural, not budgetary**: **one iPhone app + one widget extension**. Everything that ships inside those two targets is fair game; anything needing a new target or a new platform is post-v1.

| Surface | Status |
|---|---|
| Liquid Glass (system `glassEffect`, glass button styles) | **v1** — §12.3 |
| Widgets: Home S/M/L + Lock Screen (circular, rectangular, inline) | **v1** (M5) |
| Live Activity + Dynamic Island (local updates, no push) | **v1** (M5) |
| App Intents / Siri / Shortcuts / App Shortcuts | **v1** (M4) |
| Control Center control (`ControlWidget` in the widget extension) | **v1** — no new target, high visibility, cheap |
| StandBy | **free** — Lock Screen widgets already render there; no work, do not budget it |
| Foundation Models reason text + deterministic fallback | **v1** (M4) |
| Swift Charts tide curve | **v1** (M3 detail) |
| MapKit focus map + spot switcher | **v1** (M3) |
| Dynamic Type AX5, VoiceOver, Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, Differentiate Without Colour | **v1, release gate** (M3 + M6) |
| Haptics, TipKit, App Review prompt | **v1** |
| MeshGradient ocean background, symbol effects, zoom navigation transition, numeric content transition, scroll transitions | **v1 polish** — cheap, visible, first-impression value |
| Spotlight indexing of the two spots (`AppEntity` + `IndexedEntity`) | **v1 if time**, else first post-v1 |
| WeatherKit (wind, temperature, precipitation, visibility) + Open-Meteo Marine (swell) | **v1** (M2) |

**Post-v1, explicitly out**: watchOS app or complication, App Clip, visionOS, Mac Catalyst, any push backend, live marine chart overlays. Each needs a new target or a new platform; none is a missing feature of the phone app.

The product is still free, ad-free and subscription-free. The developer membership is the only unavoidable cost and it is already covered.

### 12.3 Surfaces are system glass, not materials

"Liquid Glass" in the brief means the **system API**, not a blur. `.ultraThinMaterial` is the pre-iOS 26 look: it has no refraction, no specular edge, no blending between adjacent shapes, and it does not participate in the iOS 27 glass behaviours. For a product whose entire premise is « vitrine iOS 27 », shipping materials behind a comment that says "Liquid Glass" is the one visible tell that the app is not native to its OS.

- Cards, tiles and floating controls use `glassEffect(_:in:)` inside a `GlassEffectContainer` when two or more glass shapes can morph or blend (the `SpotSwitcher` chips, the answer card + segmented control pair).
- Controls use `.buttonStyle(.glass)` / `.glassProminent`; the system tab bar already renders Liquid Glass and must not be re-drawn.
- The whole app goes through **one** modifier (`oceanGlassCard` / `oceanGlassCapsule`). Swapping material → glass must stay a one-file change; no screen may reach for a background style directly.
- `Reduce Transparency` swaps glass for an opaque surface, `Increase Contrast` strengthens the hairline, `Reduce Motion` removes the morph. These are read from the environment in the modifier, not per screen.
- The exact iOS 27 signature must be confirmed against the SDK on the Mac mini; until then the modifier keeps a `#if compiler` / availability branch. This is the same class of uncertainty as the Foundation Models API in M4.

### 12.4 State truth rules (no invented value, no false equivalence)

Three rules that the UI must never break, because each one produces a number or a verdict the data does not support:

1. **No silent zero.** A missing measurement renders « — », never `0`, `0,0 m` or `0 km/h`. `current?.height ?? 0` is a bug, not a fallback: it tells a local the water is at chart datum when the app simply has no event.
2. **Unavailable is not "none".** When an activity is in `unavailableActivities`, the window card says « Créneaux indisponibles » — never « Aucun créneau dans les 48 prochaines heures ». The second sentence is a claim about the sea; the first is a claim about our data. Baignade at v1 is exactly this case.
3. **No coefficient in v1.** `coefficientSource` is `.localProxy` on every spot, so the number is not the national coefficient and the word « coef local estimé » is noise that invites a question the app cannot answer. The reason line shows the next tide event only (« Marée basse à 14 h 12 »). The coefficient returns, in the mockup's position, only when `coefficientValidated` is true.

**Colour scheme**: v1 is **dark-only by design** (night-sea palette, forced at the root). The palette has no light variants and §12's earlier "dynamic dark variants" wording is corrected: there is one scheme, and the showcase value is in the glass and the motion, not in a second palette. Revisit post-v1.

### 12.5 iOS UI inventory — what « à fond » means, item by item

Anthony's instruction (2026-10-27): *« tout ce qui est iOS 27 qu'on peut implémenter, on y va à fond côté UI »*. This is the concrete list. Every row has an owner milestone and an acceptance test; nothing here is "nice to have later".

| # | Surface | API | Behaviour | Gate |
|---|---|---|---|---|
| 1 | Liquid Glass | `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `glassEffectID` + `@Namespace` | Cards, tiles, chips and the spot switcher are real glass; two adjacent glass shapes morph, not two blurs side by side | M3 |
| 2 | Animated ocean background | `MeshGradient` (3×3) | Slow 8–12 s loop behind the Home scroll; **static under Reduce Motion**; paused when the scene is inactive | M3 |
| 3 | Verdict motion | `.symbolEffect(.bounce, value:)`, `.contentTransition(.symbolEffect(.replace))` | The Oui/Non icon reacts when the verdict changes, never when the view simply redraws | M3 |
| 4 | Numeric transitions | `.contentTransition(.numericText())` | Tide height, wind, temperature, times roll instead of snapping | M3 |
| 5 | Zoom navigation | `.navigationTransition(.zoom(sourceID:in:))` + `.matchedTransitionSource` | The spot card grows into the spot detail (tide chart); Reduce Motion → cross-fade | M3 |
| 6 | Scroll choreography | `.scrollTransition` on cards; tab bar minimise on scroll | Cards settle as they enter; a one-shot, not a perpetual parallax | M3 |
| 7 | Haptics | `.sensoryFeedback` | One tap when the verdict state changes; none on load, none on redraw | M3 |
| 8 | Launch screen | `UILaunchScreen` background colour = `oceanDeepTop` | No white flash between the icon tap and the first frame | M3 |
| 9 | Widgets | WidgetKit, `containerBackground` for Home, none for accessory | Home S/M/L + `accessoryCircular / Rectangular / Inline`; same snapshot and same spot as the app | M5 |
| 10 | StandBy | *(no code)* | Consequence of good Lock Screen widgets: legible on pure black, no background, no clipping at large sizes. The effort goes into item 9, not into a "StandBy feature" | M5 |
| 11 | Live Activity + Dynamic Island | ActivityKit, `ActivityConfiguration` | Compact / expanded / minimal; local updates only; no push | M5 |
| 12 | Control Center | `ControlWidget` + `OpenIntent`, inside the widget extension | One control: current spot + verdict, tap opens the app on that spot. Label refreshed from the App Group snapshot | M5 |
| 13 | Siri / Shortcuts | App Intents, `AppShortcutsProvider`, `SpotEntity` | French phrases, one-tap answers, no configuration required | M4 |
| 14 | Spotlight | `IndexedEntity` | The two spots are findable in Spotlight | post-v1 if time |
| 15 | TipKit | 1–2 tips maximum | One for the spot switcher, one for alerts; never on first launch | M4 |
| 16 | Review prompt | `RequestReviewAction` | After the third good window viewed, never on launch, once per version | M6 |

**Hard rules for all of it**

- Every animation has a **Reduce Motion** path, every glass surface a **Reduce Transparency** path, every symbol an accessibility label. A showcase that breaks the accessibility settings is a failed showcase.
- No custom tab bar, no custom navigation chrome: the system ones are Liquid Glass for free and stay correct across OS updates.
- Nothing that needs a new target or a new platform (§12.2).
- 120 Hz budget: `MeshGradient` is the only continuously animating layer, no `.drawingGroup()`, no stacked blurs, and it pauses off-screen.
- **iOS 27 additions are decided at build #1, not invented now.** The v1 list above is built on APIs that exist up to iOS 26. At the first Mac build, inventory what iOS 27 adds (widget families, Siri surfaces, system controls) and bring a short-list with a cost estimate; the architect decides what enters v1. Do not write against an API whose signature has not been seen.

---

## 13. Localization & accessibility

- Single localization: **French** (base). All UI strings in `Localizable.xcstrings`.
- Copy style: short, tutoiement (« C'est un bon moment pour sortir. », « Parfait pour la pêche à pied. »).
- **Accessibility is a release gate, not a polish item.** This app is an iOS 27 showcase: a screen that breaks at large text or is unusable with VoiceOver undermines the whole point. Every screen must be usable at **Dynamic Type AX5** and pass a VoiceOver pass before M6 closes.
- **Dynamic Type**: no fixed height on any text container; `.fixedSize(horizontal: false, vertical: true)` where a label must wrap; layouts reflow to vertical stacks at accessibility sizes (`@Environment(\.dynamicTypeSize)`); the Oui/Non display numeral scales with `relativeTo: .largeTitle`; `.dynamicTypeSize(...)` is allowed only with a written justification; widgets and Live Activity layouts must not clip at large sizes.
- **VoiceOver**: the verdict is one element, read as a sentence (« Oui, pêche à pied, marge suffisante »); colour is never the only signal — every verdict carries text and an icon; the tide chart exposes the next event as an accessibility value or a text summary.
- **Label parity**: a combined element must read **everything it displays**. If the sighted user sees « Marée basse à 14 h 12 » under the verdict, the VoiceOver label says it too. An `.accessibilityElement(children: .ignore)` that drops the detail line is a regression, not a simplification.
- **Touch targets**: every tappable control is at least **44 × 44 pt** at the default text size, independent of its visual padding. The 13 pt chips (activity picker, spot switcher, toolbar spot button) are ~32 pt tall with their current padding — they need an explicit `minHeight`. At accessibility sizes the content grows past 44 on its own.
- **Unavailable states are announced as states**: VoiceOver reads « Données indisponibles » plus the reason, never « Non » and never silence.
- **Other signals**: Reduce Motion (cross-fade instead of spring), Reduce Transparency (glass → opaque surface), Increase Contrast, Bold Text, Differentiate Without Colour.
- **Contrast**: sand/blue and Oui/Non pairs verified ≥ 4.5:1 for body text; the 76pt numeral is treated as a graphic and always paired with a label.
- `stop-slop-fr` review pass on all user-facing French copy before release (no AI-isms).

---

## 14. Testing strategy

| Layer | Tests |
|---|---|
| **Domain (EstranCore)** | Unit tests for `TideEngine` (known reference tides), `DecisionEngine` (golden scenarios per activity), `nextGoodWindow` scanning, coefficient formula, `TemplateReasonProvider`. |
| **Data** | Mocks/recorded fixtures for Open-Meteo JSON; WeatherKit mocked; codable round-trips; cache TTL. |
| **UI** | SwiftUI previews as dev tooling; `EstranUITests` for the Home happy path; snapshot tests for `GoBadge` states (optional). |
| **Rules calibration** | A fixture set of real historical conditions with expected Oui/Non, used as a regression harness. |

Golden-scenario fixtures live in `EstranCore/Tests/` and are shared by both agents' work.

---

## 15. Milestones

Each milestone ends with a **review gate** (see §17) before merging into `dev`.

| Milestone | Deliverable | Review gate |
|---|---|---|
| **M0 — Setup** | Xcode project with 2 product targets — `Estran` (app) + `EstranWidgets` (widget + Live Activity/ActivityKit) — plus the local `EstranCore` package skeleton, App Group, entitlements, SwiftData container, theme tokens, CI (xcodebuild + swiftlint). | Builds & archives; targets wired. |
| **M1 — Domain core** | Models, `TideEngine` + constants, `DecisionEngine` + 5 rules, unit tests, golden fixtures. | Rule logic reviewed; tests green. |
| **M2 — Data** | `WeatherKitService`, `MarineService` (Open-Meteo), `SpotsCatalog`, `ConditionsProvider`, caching. | Data pipeline correct; offline-safe. |
| **M3 — UI** | Home, Spot detail (tide chart), Activity picker, onboarding, Liquid Glass theming, 2-spot focus map + switcher. Built at Dynamic Type AX5 from the first screen, not retrofitted. | UI matches Figma; flows work; AX5 and VoiceOver pass. |
| **M4 — Intelligence** | Foundation Models provider + fallback, `CheckConditionsIntent` + `AppShortcut`, local notifications. | Siri + text fallback correct. |
| **M5 — Glanceable** | Widgets (Home S/M/L + Lock Screen), Live Activity + Dynamic Island, background refresh. | Answer visible without app. |
| **M6 — Polish & ship** | Full accessibility audit (AX5, VoiceOver, Reduce Motion/Transparency, contrast), `stop-slop-fr` copy pass, performance, TestFlight build. | Release-ready. |

---

## 16. Tooling & project generation

- **Xcode 26+** / iOS 27 SDK, Swift 6 (`SWIFT_STRICT_CONCURRENCY: complete`), deployment target iOS 27.0.
- Project generated with **XcodeGen** (`project.yml`) or kept as `.xcodeproj`; decision in M0 (XcodeGen preferred for a multi-target + local SPM layout that's diff-friendly). `Estran.xcodeproj` is committed, so a clone builds without `xcodegen`; regenerate after any `project.yml` change.
- **swiftlint** / **SwiftFormat** for style (enforced in CI).
- **CI**: GitHub Actions — build, test, lint on PR.
- Secrets: WeatherKit uses the app's signing entitlement (no key in repo). No API keys (Open-Meteo is keyless).

### 16.1 Build strategy — the dev host cannot compile the app

The development host is Linux. `swift build` / `swift test` cover **`EstranCore` only**; the 2 000+ lines of SwiftUI, the widget extension and the App Intents have **never been compiled**. Anthony builds on his Mac, at the end. That is a deliberate choice and it is workable, but it changes what "done" means at each milestone: a milestone whose UI has not compiled is *written*, not *done*.

Three build checkpoints, no more:

1. **M3 close** — the app target compiles and launches on a simulator with the DEBUG demo provider. This is the highest-value build: it validates the target graph, the App Group, the Swift 6 concurrency model and the iOS 27 API surface (Liquid Glass, MapKit, Charts) before anything else is built on top.
2. **M5 close** — widgets, Live Activity, Control Center and App Intents compile and render. These are the most SDK-sensitive targets (extension + `WidgetKit` + `ActivityKit` + `ControlWidget`).
3. **Pre-TestFlight** — signed archive, WeatherKit capability live, privacy manifest present, TestFlight upload.

If a checkpoint cannot happen, the fallback is an **unsigned CI build** (`CODE_SIGNING_ALLOWED=NO`) on a free GitHub Actions macOS runner — it type-checks the whole target graph without certificates. Verify that the runner image ships the iOS 27 SDK before relying on it.

**Signing and portal setup are manual and cannot be done from this host.** The checklist lives in [`BUILD.md`](BUILD.md): App IDs, App Group registration, WeatherKit capability, `DEVELOPMENT_TEAM`, privacy manifest, archive and TestFlight.

---

## 17. Git workflow & collaboration

- **Branching** (per project): `feat/<name>` branched from an **up-to-date `dev`**; `main` = production. (The full Forge flow `feat → dev → staging → main` collapses to `feat → dev → main` here, since there is no backend/staging server for an on-device app.)
- Commits, branch names, PRs: **English**, concise.
- **File ownership** is defined in `worksplit.md` (to be authored with Kimi) so the two agents edit disjoint files and merge cleanly.
- **Code review protocol (this agent, as Lead Reviewer):**
  - Strict reviews; report **only blocking issues or architecture errors** in `.md` report files (e.g. `review/M1-review.md`).
  - Non-blocking style nits are left to linters; no noise.
  - Reviews are per-milestone and gated on the milestone's checklist above.

---

## 18. Open questions & assumptions (to resolve)

1. **Spot list** — ✅ **scope revised by Anthony (2026-10-27): v1 ships 2 spots only** — Pointe de Grave / Le Verdon and Arcachon-Eyrac — the two with a REFMAR gauge. The 14-spot coastal catalog (Pointe de Grave → Pyla, including Andernos, Arès, Gujan-Mestras) remains the **post-v1 target** and is kept in `DESIGN_REFERENCE.md §4` as a roadmap, not as shipped content. *Remaining: verify the 2 coordinates against IGN/SHOM, and finalize the `coastOrientationDegrees` / `minimumWaterHeight` values for those 2 spots.*
2. **Tide data source** — **0 € route adopted:** REFMAR observations (Licence Ouverte 2.0) → build-time harmonic analysis → embedded constants. No SHOM purchase, no SAPM, no runtime API. The derived model is an estimation, not a SHOM-official prediction. **D3 revised by Anthony: Option A (2026-10-27)** — v1 ships **2 gauged spots only** (1 Pointe de Grave, 10 Arcachon-Eyrac); the 12 estimated spots are out of the v1 catalog. Both spots say « modèle local — station 15 » / « station 190 », never « estimation » and never « mesure locale ». Fail-closed gates with a bound-based envelope. *Remaining: baignade — architect decision pending (gate on the local predicted range instead of the national coefficient). M1 otherwise closed as of `review.md` v8; the next gate is the M3 build checkpoint on the Mac.*
3. **Foundation Models API surface** — exact `FoundationModels` API on iOS 27 (isolated behind `ReasonTextProviding`).
4. **Figma mockups** — ✅ delivered and extracted (`DESIGN_REFERENCE.md`).
5. **iOS floor** — target is iOS 27.0. Confirm whether an iOS 26 floor is needed (Liquid Glass/Foundation Models both require 26; widgets/Live Activity fine on 26).
6. **WeatherKit entitlement** — ✅ **resolved 2026-10-27**: Anthony has a paid Apple Developer Program membership and a Mac with Xcode. The WeatherKit capability still has to be enabled on the App ID in the portal (see `BUILD.md`), and the build happens on his Mac at the milestone checkpoints of §16.1, not on this host.
7. **Baignade water temp** — sourced from Open-Meteo SST; confirm if an alternative (in-situ) source is preferred.

---

## 19. First-step blockers (for the other agent / next session)

- Await **Figma mockups** to finalize the screen inventory and UI components.
- Await **spot list** to seed `SpotsCatalog`, and the SHOM data route decision (tables vs constants) before embedding tide data.
- Then produce **`worksplit.md`** (file ownership) with Kimi and begin M0.
