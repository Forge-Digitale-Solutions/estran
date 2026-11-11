# iOS 27 SDK Opportunity Audit — Estran

**Audit date:** 2026-11-11  
**Target hardware:** Classic iPhone family (iPhone 17 / 18 / Pro / Pro Max — Super Retina XDR, Dynamic Island; no foldables, no iPad)  
**SDK ground truth on disk:** `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.2.sdk` (Xcode 27.2, build `27B52`)  
**Scope:** Research-only audit of what the installed iOS 27.2 SDK (and unused iOS 26 / 18 APIs in the same SDK) offers that Estran does not yet use.

Every API recommended in Section 2 is backed by its **verbatim `.swiftinterface` declaration** from `iPhoneOS27.2.sdk` and marked **VERIFIED IN SDK**.

---

## 1. Already Used (`API → File`)

Inspection of `Estran/`, `EstranWidgets/`, and `Packages/EstranCore/` shows that Estran already compiles against the iOS 27 SDK and uses a foundational subset of Liquid Glass, Observation, Swift Charts, MapKit, WidgetKit, ActivityKit, AppIntents, FoundationModels, WeatherKit, and SwiftData — while leaving almost all of the **interactive, morphing, choreographed, and iOS 27-specific** APIs unused (including several explicitly planned in `ARCHITECTURE_PLAN.md` §12.5).

### 1.1 Liquid Glass (`SwiftUI` / `SwiftUICore`, iOS 26.0+)

| API in use | File(s) | Current usage notes |
|---|---|---|
| `.glassEffect(.regular, in: shape)` | `Estran/Theme/GlassStyles.swift` (`OceanGlassSurfaceModifier`) | Backs `.oceanGlassCard(cornerRadius:)` (`RoundedRectangle(cornerRadius: 20, style: .continuous)`) and `.oceanGlassCapsule()` (`Capsule(style: .continuous)`), plus the `accessibilityReduceTransparency` opaque fallback (`OceanPalette.deepNavy.opacity(0.92)`). |
| `.glassEffect(.regular, in: Circle())` | `Estran/Features/ActivityPicker/ActivityPickerView.swift` | Circular close (`xmark`) and confirmation (`checkmark`) buttons in the top bar. |
| `Glass.regular.tint(OceanPalette.white)` + `.glassEffect(glass, in: Capsule(style: .continuous))` | `Estran/Features/Home/Components/ActivitySegmentedControl.swift`, `Estran/Features/Spots/SpotSwitcher.swift` | Selected vs. unselected capsule pills (`selected ? Glass.regular.tint(OceanPalette.white) : .regular`). Uses neither `.interactive()` nor `glassEffectID(_:in:)`. |
| `GlassEffectContainer(spacing:content:)` | `Estran/Features/Home/HomeView.swift` (`spacing: 14`), `Estran/Features/Home/Components/ActivitySegmentedControl.swift` (`spacing: 6`), `Estran/Features/Spots/SpotSwitcher.swift` (`spacing: 8`), `Estran/Features/ActivityPicker/ActivityPickerView.swift` (`spacing: 10`) | Groups adjacent glass surfaces in a shared rendering pass, but without `glassEffectID` or `glassEffectUnion`, no morphing or capsule fusion occurs. |
| `.buttonStyle(.glass)` | `Estran/Features/Shared/SmallComponents.swift` (`SpotButton`) | Used on the standalone `SpotButton` helper (not currently mounted on the primary `HomeView` header, which uses `.oceanGlassCapsule()` directly). |

### 1.2 Navigation, Tabs & Layout (`SwiftUI`)

| API in use | File(s) | Current usage notes |
|---|---|---|
| `TabView(selection:)` with legacy `.tabItem { Label(...) }.tag(...)` | `Estran/App/RootView.swift` | Uses pre-iOS 18 `.tabItem` modifier rather than the `Tab` struct; does not set `.tabBarMinimizeBehavior` or `.tabViewBottomAccessory`. |
| `NavigationStack` + `.navigationDestination(isPresented:)` | `Estran/App/RootView.swift`, `Estran/Features/Spots/SpotsView.swift` | `SpotsView` pushes `SpotDetailView` via boolean binding without `.matchedTransitionSource` or `.navigationTransition(.zoom(...))`. |
| `ViewThatFits(in: .horizontal)` | `Estran/Features/Home/Components/AnswerCard.swift`, `Estran/Features/SpotDetail/SpotDetailView.swift`, `Estran/Features/SpotDetail/TideChartCard.swift`, `Estran/Features/ActivityPicker/ActivityPickerView.swift` | Switches horizontal layouts to vertical stacks at large Dynamic Type sizes. |
| `@ScaledMetric` | `Estran/Features/Home/Components/AnswerCard.swift`, `ConditionsGrid.swift`, `SwimmingAdvisoryCard.swift`, `Estran/Features/SpotDetail/SpotDetailView.swift`, `TideChartCard.swift`, `ActivityOverviewList.swift`, `Estran/Features/ActivityPicker/ActivityPickerView.swift` | Scales icon wells, pill heights, and chart heights with Dynamic Type (`relativeTo:`). |

### 1.3 Accessibility Environment (`SwiftUI`)

| API in use | File(s) | Current usage notes |
|---|---|---|
| `@Environment(\.accessibilityReduceTransparency)` | `Estran/Theme/GlassStyles.swift`, `Estran/Features/Home/Components/ActivitySegmentedControl.swift`, `Estran/Features/Spots/SpotSwitcher.swift`, `Estran/Features/ActivityPicker/ActivityPickerView.swift` | Replaces `.glassEffect(...)` with opaque `OceanPalette.deepNavy.opacity(0.92)` and high-contrast strokes. |
| `@Environment(\.colorSchemeContrast)` | `Estran/Theme/GlassStyles.swift`, `Estran/Theme/OceanPalette.swift`, `Estran/Features/Home/Components/ActivitySegmentedControl.swift`, `AnswerCard.swift`, `Estran/Features/Spots/SpotSwitcher.swift`, `Estran/Features/SpotDetail/TideChartCard.swift`, `Estran/Features/ActivityPicker/ActivityPickerView.swift` | Widens border strokes (`1.5 pt`–`2 pt`) and switches subtle white alphas to `OceanPalette.textSubtle(for: contrast)` when `.increased`. |
| `@Environment(\.dynamicTypeSize)` | `Estran/Features/Home/HomeView.swift`, `ActivitySegmentedControl.swift`, `ConditionsGrid.swift`, `Estran/Features/Spots/SpotsView.swift`, `Estran/Features/SpotDetail/SpotDetailView.swift`, `TideChartCard.swift`, `ActivityOverviewList.swift` |Collapses 2×2 grids to 1-column stacks and segmented controls to a `Menu` when `dynamicTypeSize.isAccessibilitySize`. |
| `@Environment(\.accessibilityVoiceOverEnabled)` | `Estran/Features/SpotDetail/TideChartCard.swift` | Suppresses the drag-scrub gesture on the tide chart when VoiceOver is running so rotor navigation works cleanly. |
| `.accessibilityRepresentation` / `.accessibilityChartDescriptor` | `Estran/Features/SpotDetail/TideChartCard.swift` | Exposes high/low tide extrema as discrete VoiceOver elements alongside `AXChartDescriptor`. |

> [!NOTE]
> `@Environment(\.accessibilityReduceMotion)` and `@Environment(\.accessibilityPrefersCrossFadeTransitions)` have **zero occurrences** in `Estran/` today because none of the planned motion (`MeshGradient`, `.symbolEffect`, `.contentTransition(.numericText())`, `.navigationTransition(.zoom)`, `.scrollTransition`) has been wired yet.

### 1.4 Charts, MapKit, Observation, SwiftData & WeatherKit

| Framework / API in use | File(s) | Current usage notes |
|---|---|---|
| `Charts`: `Chart`, `AreaMark`, `LineMark` (`.interpolationMethod(.catmullRom)`), `RectangleMark`, `RuleMark`, `PointMark`, `.chartOverlay` (`ChartProxy`), `AXChartDescriptorRepresentable` | `Estran/Features/SpotDetail/TideChartCard.swift` | 24 h tide curve with shaded green feasibility windows, "Maintenant" vertical rule, PLEINE MER / BASSE MER callouts, and touch scrubbing. |
| `MapKit`: `Map(position: $camera, interactionModes: [])`, `Marker`, `.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))` | `Estran/Features/Spots/SpotsView.swift` | Static overview map behind the two spot cards (`Pointe de Grave`, `Arcachon — Jetée d'Eyrac`). |
| `Observation`: `@Observable` | `Estran/App/AppModel.swift` (`ForecastStore`, `AppModel`), `Estran/App/RootView.swift` (`.environment(app)`) | Drives state across the 4 tabs. |
| `FoundationModels`: `SystemLanguageModel.default.availability`, `LanguageModelSession(model:instructions:)`, `session.respond(to: String, options: GenerationOptions)` | `Estran/Reason/FoundationModelReasonProvider.swift` | Generates a 1-sentence French `reason` string gated by `FoundationModelReasonProvider.isAcceptable(_:decision:)` (blocks `"oui"` for swimming, `"shom"`, `"officiel"`, and invented digits). Not yet using `@Generable` structured decoding. |
| `AppIntents`: `AppIntent` (`AnswerIntent`, `OpenEstranIntent`), `AppEnum` (`SpotChoice`, `ActivityChoice`), `AppShortcutsProvider` (`EstranShortcuts`), `AppShortcut` | `Estran/Intents/EstranIntents.swift`, `EstranWidgets/Control/EstranControl.swift` | Spoken/dialog Siri answer and Control Center launcher. |
| `WidgetKit`: `StaticConfiguration`, `.containerBackground(for: .widget)`, `.supportedFamilies([.systemSmall, .systemMedium])`, `ControlWidget`, `StaticControlConfiguration`, `ControlWidgetButton` | `EstranWidgets/GoWidget.swift`, `EstranWidgets/ConditionsWidget.swift`, `EstranWidgets/Control/EstranControl.swift` | Small/medium Home Screen widgets and Control Center button. |
| `ActivityKit`: `ActivityConfiguration`, `DynamicIsland`, `DynamicIslandExpandedRegion`, `.activityBackgroundTint`, `Activity<GoActivityAttributes>.request` / `.update` / `.end` | `EstranWidgets/LiveActivity/GoLiveActivityView.swift`, `Estran/LiveActivity/LiveActivityController.swift` | Lock Screen banner and Dynamic Island Live Activity (`LiveActivityController` exists in `Estran/LiveActivity/` ready to be driven by user action). |
| `WeatherKit`: `WeatherService.shared.weather(for:including: .current, .hourly)` | `Estran/Data/WeatherKitService.swift` | Weather adapter with Open-Meteo fallback in `LiveForecastProvider.swift`. |
| `SwiftData`: `@Model`, `ModelContainer`, `ModelConfiguration` | `Packages/EstranCore/Sources/EstranCore/Persistence/EstranModelContainer.swift` | Local persistence for `UserPreferences`, `WeatherCacheEntry`, `WaterTempCacheEntry`. |

---

## 2. Ranked Opportunities (Visual Impact / Effort / Risk)

The 12 opportunities below are ordered by **highest visual "wow" per unit of implementation risk** on iPhone 17/18 devices running iOS 27.

| Rank | Opportunity | Min OS | Visual Impact | Effort | Risk | Primary Surface(s) |
|---|---|---|---|---|---|---|
| **1** | Interactive & Morphing Liquid Glass (`Glass.interactive`, `glassEffectID`, `glassEffectTransition`, `glassEffectUnion`) | iOS 26.0 | Very High | Low | Low | `Home`, `Spots`, `ActivityPicker` |
| **2** | Animated `MeshGradient` Ocean Backdrop + HDR Headroom (`Color.headroom`) | iOS 18.0 / 26.0 | Very High | Low | Low | `Home`, `SpotDetail`, `ActivityPicker` |
| **3** | iOS 27 `TabsPickerStyle` (`.pickerStyle(.tabs)`) for the Single-Track Activity Bar | **iOS 27.0** | High | Low | Low | `Home` (`ActivitySegmentedControl`) |
| **4** | Verdict Motion, Numeric Rolling, Scroll Choreography & Selection Haptics (`symbolEffect`, `numericText`, `scrollTransition`, `SensoryFeedback.selection`) | iOS 17.0 / 26.0 | High | Low | Low | `Home` (`AnswerCard`, `ConditionsGrid`), `SpotDetail` |
| **5** | Spot-to-Detail Zoom Transition + iOS 27 `.crossFade` Accessibility Transition | iOS 18.0 / **27.0** | High | Low | Low | `Spots` → `SpotDetail` |
| **6** | Scroll Edge Glass & Background Extension (`scrollEdgeEffectStyle`, `backgroundExtensionEffect`) | iOS 26.0 | High | Low | Low | `Home`, `SpotDetail`, `Spots` |
| **7** | Modern `Tab` API + `.tabBarMinimizeBehavior(.onScrollDown)` + `.tabViewBottomAccessory` + iOS 27.1 `prefersTabBar` | iOS 26.0 / **27.1** | High | Medium | Low | `RootView` (all 4 tabs) |
| **8** | Concentric Corner Geometry (`ConcentricRectangle` / `.rect(corners: .concentric)` + `.containerShape`) | iOS 26.0 | Medium–High | Low | Low | `Home`, `SpotDetail`, `ActivityPicker`, Widgets |
| **9** | iOS 27 Dynamic Island Width Adaptation (`\.isDynamicIslandLimitedInWidth`) + Widget `\.levelOfDetail` & `.supportedMountingStyles` | **iOS 27.0** / 26.0 | Medium–High | Low | Low | Live Activity, `GoWidget`, `ConditionsWidget` |
| **10** | Foundation Models `@Generable` / `@Guide` Structured Copy & iOS 27 `DynamicProfile` + `prewarm` | **iOS 27.0** | Medium | Medium | Low | `Home` (`AnswerCard` reason + `TipCard`) |
| **11** | iOS 27 Scene Accessories (`sceneAccessory`, `ExternalNonInteractiveAccessory`) | **iOS 27.0** | Medium | Medium | Medium | `RootView` / iPhone cover & stand accessory |
| **12** | iOS 27 Spotlight `IndexedEntityQuery` + `@ComputedProperty(indexingKey:)` + `TargetContentProvidingIntent` | **iOS 27.0** / 26.0 | Medium | Medium | Low | Siri / Spotlight / Shortcuts → `SpotDetail` |

---

### Opportunity 1 — Interactive & Morphing Liquid Glass (`Glass.interactive`, `glassEffectID`, `glassEffectTransition`, `glassEffectUnion`)

- **Status:** **VERIFIED IN SDK** (`SwiftUICore.swiftinterface`, lines 3528–3545, 7418–7433, 12825–12828, 22701–22704)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
  @available(visionOS, unavailable)
  public struct Glass : Swift::Equatable, Swift::Sendable {
    public static var regular: SwiftUICore::Glass { get }
    public static var clear: SwiftUICore::Glass { get }
    public static var identity: SwiftUICore::Glass { get }
    public func tint(_ color: SwiftUICore::Color?) -> SwiftUICore::Glass
    public func interactive(_ isEnabled: Swift::Bool = true) -> SwiftUICore::Glass
  }

  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
  @available(visionOS, unavailable)
  public struct GlassEffectTransition : Swift::Sendable {
    public static var materialize: SwiftUICore::GlassEffectTransition { get }
    @available(iOS 26.1, macOS 26.1, tvOS 26.1, watchOS 26.1, *)
    @available(visionOS, unavailable)
    public static var identity: SwiftUICore::GlassEffectTransition { get }
    public static func matchedGeometry(isEnabled: Swift::Bool = true) -> SwiftUICore::GlassEffectTransition
  }

  extension SwiftUICore::View {
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
    @available(visionOS, unavailable)
    nonisolated public func glassEffectID(_ id: (some (Hashable & Sendable))?, in namespace: SwiftUICore::Namespace.SwiftUICore::ID) -> some SwiftUICore::View

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
    @available(visionOS, unavailable)
    @_Concurrency::MainActor @preconcurrency public func glassEffectTransition(_ transition: SwiftUICore::GlassEffectTransition) -> some SwiftUICore::View

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
    @available(visionOS, unavailable)
    @_Concurrency::MainActor @preconcurrency public func glassEffectUnion(id: (some (Hashable & Sendable))?, namespace: SwiftUICore::Namespace.SwiftUICore::ID) -> some SwiftUICore::View
  }
  ```
- **Target Estran screen(s):**
  - `Home`: `ActivitySegmentedControl` (`Estran/Features/Home/Components/ActivitySegmentedControl.swift`), top spot capsule & gear button (`Estran/Features/Home/HomeView.swift`), and the `SwimmingAdvisoryCard` / `AnswerCard` transition inside `HomeView`'s `GlassEffectContainer`.
  - `Spots`: `SpotSwitcher` (`Estran/Features/Spots/SpotSwitcher.swift`).
  - `ActivityPicker`: top circular close/confirm buttons and activity rows (`Estran/Features/ActivityPicker/ActivityPickerView.swift`).
- **What it would look like:**
  - Today, tapping an activity in `ActivitySegmentedControl` or a spot in `SpotSwitcher` snaps a static white tint from one capsule to another, and the buttons do not respond with Liquid Glass specular deflection on touch down.
  - Adding `.interactive()` to the `Glass` value on tappable capsules (`Glass.regular.interactive()` and `Glass.regular.tint(OceanPalette.white).interactive()`) makes every pill subtly swell, catch specular light along the finger vector, and refract the ocean glow underneath on touch.
  - Adding `@Namespace private var glassNamespace` + `.glassEffectID(activity, in: glassNamespace)` + `.glassEffectTransition(.matchedGeometry())` inside `GlassEffectContainer` causes the active white-tinted glass pill to **fluidly stretch like a droplet of water** from `Surf` to `Pêche` or `Baignade`, and when switching to `Baignade`, the `AnswerCard` and `SwimmingAdvisoryCard` morph via `.glassEffectTransition(.materialize)` rather than popping in abruptly.
  - Using `.glassEffectUnion(id: "activityBar", namespace: glassNamespace)` on unselected segments fuses the 5 separate capsules into a single continuous Liquid Glass track (matching Figma Frame 01's outer pill track) while still allowing individual button hit targets.
- **Accessibility implications:**
  - **Reduce Transparency:** Already guarded in `OceanGlassSurfaceModifier`, `ActivitySegmentedControl`, and `SpotSwitcher` (`if reduceTransparency` bypasses `.glassEffect` and draws `OceanPalette.deepNavy.opacity(0.92)` with a solid border). Keep `.glassEffectID` inside the `else` branch so opaque mode remains crisp.
  - **Reduce Motion / Cross-Fade:** Read `@Environment(\.accessibilityReduceMotion)` and `@Environment(\.accessibilityPrefersCrossFadeTransitions)`. When either is `true`, pass `.glassEffectTransition(.identity)` (available iOS 26.1+) instead of `.matchedGeometry(isEnabled: true)`, eliminating horizontal droplet stretching while keeping specular legibility.
  - **Increase Contrast:** Preserve the existing `contrast == .increased` `2 pt` white border on the selected pill.
  - **Dynamic Type AX5:** `ActivitySegmentedControl` already switches to a single `Menu` at `dynamicTypeSize.isAccessibilitySize`; apply `.interactive()` to the `Menu`'s `.oceanGlassCapsule()` surface as well.
- **Invariant check (`AGENTS.md`):**
  - Purely visual/interactive layer on existing views. When the user selects `Baignade`, `HomeView` still routes through `if app.selectedActivity == .swimming { SwimmingAdvisoryCard(...) } else { AnswerCard(...) }` — **never** rendering `Oui` for swimming (Invariant 1).

---

### Opportunity 2 — Animated `MeshGradient` Ocean Backdrop + HDR Color Headroom (`Color.headroom`)

- **Status:** **VERIFIED IN SDK** (`SwiftUICore.swiftinterface`, lines 10595–10600, 19473–19495)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  nonisolated public struct MeshGradient : SwiftUICore::ShapeStyle, Swift::Equatable, Swift::Sendable {
    public init(width: Swift::Int, height: Swift::Int, points: [Swift::SIMD2<Swift::Float>], colors: [SwiftUICore::Color], background: SwiftUICore::Color = .clear, smoothsColors: Swift::Bool = true, colorSpace: SwiftUICore::Gradient.SwiftUICore::ColorSpace = .device)
  }

  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  extension SwiftUICore::Color {
    public func headroom(_ headroom: Swift::Double?) -> SwiftUICore::Color
    @export(implementation) public func exposureAdjust(_ stops: Swift::Double) -> SwiftUICore::Color
  }
  ```
- **Target Estran screen(s):**
  - `Home` (`Estran/Features/Home/HomeView.swift`), `SpotDetail` (`Estran/Features/SpotDetail/SpotDetailView.swift`), `ActivityPicker` (`Estran/Features/ActivityPicker/ActivityPickerView.swift`), `Alertes` (`Estran/Features/Alerts/AlertsView.swift`), `Réglages` (`Estran/Features/Settings/SettingsView.swift`) via a shared `OceanBackdropView` in `Estran/Theme/OceanPalette.swift`.
- **What it would look like:**
  - Today, `OceanPalette.backgroundGradient` is a static 2-stop vertical `LinearGradient(colors: [deepNavy, navyMid])`. Liquid Glass relies on chromatic variation behind the glass to produce visible refraction and lens distortion; over a flat 2-stop gradient, `.glassEffect(.regular)` looks almost indistinguishable from a simple alpha blur.
  - Replacing the static gradient with a 3×3 `MeshGradient` that weaves `OceanPalette.deepNavy` (`#0A1628`), `OceanPalette.navyMid` (`#0F2847`), and the two `DESIGN_REFERENCE.md` §1 ambient glow accents (`turquoise #30D5C8` at 18% opacity top-left and `blueGlow #0091FF` at 14% opacity bottom-right) — driven by a slow 10-second sinusoidal drift (`TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active))`) — gives every `.oceanGlassCard` genuine sub-surface caustics to refract.
  - On iPhone 17/18 Super Retina XDR displays, applying `.headroom(1.25)` selectively to the `AnswerCard` verdict dot/badge (`OceanPalette.goGreen` / `OceanPalette.cautionAmber`) and the active "Maintenant" `PointMark` on `TideChartCard` gives the status indicator a subtle, jewel-like EDR glow without blowing out text contrast.
- **Accessibility implications:**
  - **Reduce Motion:** When `@Environment(\.accessibilityReduceMotion)` is `true` (or `@Environment(\.scenePhase) != .active`), `TimelineView` is paused at `t = 0` so the 3×3 mesh renders as a zero-CPU static art-directed gradient (`ARCHITECTURE_PLAN.md` §12.5 #2).
  - **Reduce Transparency:** When `accessibilityReduceTransparency` is `true`, cards use opaque `deepNavy.opacity(0.92)` so background mesh luminance never bleeds through card text.
  - **Increase Contrast:** Keep mesh glow opacities capped (`<= 0.18`) and clamp to `0.08` when `colorSchemeContrast == .increased` so WCAG AAA foreground contrast (`docs/accessibility/contrast-audit.md`) is strictly preserved.
  - **Dynamic Type AX5:** Background ignores safe area and does not affect layout geometry.
- **Invariant check (`AGENTS.md`):**
  - Purely atmospheric background + EDR accent on existing semantic colors. Never alters verdict logic, never turns swimming green, and never implies wave state from background animation.

---

### Opportunity 3 — iOS 27 `TabsPickerStyle` (`.pickerStyle(.tabs)`) for the Activity Bar

- **Status:** **VERIFIED IN SDK** (`SwiftUI.swiftinterface`, lines 16348–16359)
- **Verbatim SDK declaration:**
  ```swift
  @available(iOS 27.0, macOS 27.0, tvOS 27.0, visionOS 27.0, *)
  @available(watchOS, unavailable)
  extension SwiftUI.PickerStyle where Self == SwiftUI.TabsPickerStyle {
    @export(implementation) public static var tabs: SwiftUI.TabsPickerStyle { get }
  }

  @available(iOS 27.0, macOS 27.0, tvOS 27.0, visionOS 27.0, *)
  @available(watchOS, unavailable)
  public struct TabsPickerStyle : SwiftUI.PickerStyle {
    public init()
  }
  ```
- **Target Estran screen(s):**
  - `Home` (`Estran/Features/Home/Components/ActivitySegmentedControl.swift`) and optionally `Spots` (`Estran/Features/Spots/SpotSwitcher.swift`).
- **What it would look like:**
  - In `docs/design/figma-match-2026-10-28.md` §5, the audit noted a deliberate compromise: Figma Frame 01 specifies **one translucent Liquid Glass track containing 5 segments with a sliding white pill**, whereas `ActivitySegmentedControl.swift` had to render 5 separate capsules in an `HStack` because `.pickerStyle(.segmented)` had pre-iOS 26 styling.
  - iOS 27.0 introduces `TabsPickerStyle` (`.pickerStyle(.tabs)`), a native `PickerStyle` designed specifically for iOS 27 tab-strip selection with built-in Liquid Glass pill sliding, drag-scrubbing across segments, and automatic accessibility traits.
  - French labels remain concise in *tutoiement* context: `Surf`, `Kite`, `Kayak`, `Pêche`, `Baignade`.
  - *Note on implementation:* If `.pickerStyle(.tabs)` clips vertical icon+label stacks at standard sizes, Opportunity 1's `glassEffectUnion(id:namespace:)` + `glassEffectID(_:in:)` achieves the exact same single-track Figma Frame 01 look with full custom vertical `Image` + `Text` layout. Both are verified in `iPhoneOS27.2.sdk`.
- **Accessibility implications:**
  - **Dynamic Type AX5:** Retain the existing `if dynamicTypeSize.isAccessibilitySize` branch in `ActivitySegmentedControl.swift` that collapses the 5-item bar into a single full-width `Menu` (`"Activité : \(selected.displayName)"`), because 5 horizontal columns cannot fit `AX5` labels without truncation.
  - **VoiceOver:** Native `Picker` with `.pickerStyle(.tabs)` automatically exposes ` selected` / `1 sur 5` selection traits.
  - **Increase Contrast & Reduce Transparency:** Respects system environment values automatically.
- **Invariant check (`AGENTS.md`):**
  - Binds directly to `$app.selectedActivity` (`Activity.allCases`). Selecting `.swimming` (`Baignade`) still switches `HomeView` to `SwimmingAdvisoryCard` (Invariant 1).

---

### Opportunity 4 — Verdict Motion, Numeric Rolling, Scroll Choreography & Selection Haptics (`symbolEffect`, `numericText`, `scrollTransition`, `SensoryFeedback.selection`)

- **Status:** **VERIFIED IN SDK** (`SwiftUICore.swiftinterface` lines 20767–20769, `SwiftUI.swiftinterface` lines 1242, 5584–5612, 23850–23875)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
  public static func numericText(value: Swift::Double) -> SwiftUICore::ContentTransition

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public static func numericText(countsDown: Swift::Bool = false) -> SwiftUICore::ContentTransition

  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  extension SwiftUI.SensoryFeedback {
    public static func selection(_ feedback: SwiftUI.SensoryFeedback.SelectionFeedback) -> SwiftUI.SensoryFeedback
  }

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
  extension SwiftUICore::View {
    nonisolated public func symbolEffect<T>(_ effect: T, options: Symbols::SymbolEffectOptions = .default, value: some Equatable) -> some SwiftUICore::View where T : Symbols::DiscreteSymbolEffect, T : Symbols::SymbolEffect
    nonisolated public func scrollTransition(_ configuration: SwiftUI::ScrollTransitionConfiguration = .interactive, axis: SwiftUICore::Axis.SwiftUICore::Set? = nil, transition: @escaping @Sendable (SwiftUICore::EmptyVisualEffect, SwiftUI::ScrollTransitionPhase) -> some VisualEffect) -> some SwiftUICore::View
  }
  ```
- **Target Estran screen(s):**
  - `Home`: `AnswerCard` (`Estran/Features/Home/Components/AnswerCard.swift`), `ConditionsGrid` (`Estran/Features/Home/Components/ConditionsGrid.swift`), `NextWindowCard` (`Estran/Features/Home/Components/NextWindowCard.swift`), `SwimmingAdvisoryCard` (`Estran/Features/Home/Components/SwimmingAdvisoryCard.swift`), `ActivitySegmentedControl` (`Estran/Features/Home/Components/ActivitySegmentedControl.swift`).
  - `SpotDetail`: `SpotDetailView` (`Estran/Features/SpotDetail/SpotDetailView.swift`) and `TideChartCard` (`Estran/Features/SpotDetail/TideChartCard.swift`).
- **What it would look like:**
  - `ARCHITECTURE_PLAN.md` §12.5 items #3, #4, #6, and #7 specified these exact four polish mechanisms, and none are wired yet:
    1. **Verdict & Advisory Symbol Motion:** On `AnswerCard` and `SwimmingAdvisoryCard`, when switching between activities or when `decision.status` changes, the SF Symbol (`checkmark.circle.fill`, `exclamationmark.triangle.fill`, `xmark.circle.fill`, `questionmark.circle.fill`) morphs via `.contentTransition(.symbolEffect(.replace))` and triggers `.symbolEffect(.bounce, value: decision.status)`.
    2. **Numeric Rolling:** On `ConditionsGrid`, `SpotDetailView` (`heroStat`), and the `TideChartCard` scrub callout (`\(FrenchFormat.height(point.heightMeters))`), applying `.contentTransition(.numericText())` (animated on `forecast.tideSnapshot.heightMeters` and `selectedActivity`) makes wave height (`1,2 m`), wind (`15 nds`), water temp (`16 °C`), and scrubbed tide heights roll like precision marine instruments instead of snapping.
    3. **Scroll Transition on Lower Cards:** On `HomeView` (`NextWindowCard`, `ConditionsGrid`, `TipCard`) and `SpotDetailView` (`ActivityOverviewList`), `.scrollTransition(.animated(.smooth)) { content, phase in content.opacity(phase.isIdentity ? 1 : 0.88).scaleEffect(phase.isIdentity ? 1 : 0.97) }` gives lower glass cards a subtle depth entrance as they scroll into the viewport.
    4. **Tactile Selection Haptics:** Adding `.sensoryFeedback(.selection, trigger: app.selectedActivity)` on `ActivitySegmentedControl`, `.sensoryFeedback(.selection, trigger: app.selectedSpot)` on `SpotSwitcher`, and a light tick when crossing high/low tide extrema while scrubbing `TideChartCard` grounds the Liquid Glass visuals in crisp iPhone Taptic Engine feedback.
- **Accessibility implications:**
  - **Reduce Motion:** Gate `.symbolEffect(.bounce, ...)`, `.contentTransition(.numericText())`, and `.scrollTransition(...)` behind `@Environment(\.accessibilityReduceMotion) == false`. When Reduce Motion is on, values update instantaneously and cards remain at `scaleEffect(1.0)` and `opacity(1.0)` (`ARCHITECTURE_PLAN.md` §12.5 rule: *"All motion respects `accessibilityReduceMotion`"*).
  - **VoiceOver:** `.contentTransition(.numericText())` does not alter the `.accessibilityElement(children: .ignore)` combined label/value already set on `ConditionsGrid.tile` and `AnswerCard`.
- **Invariant check (`AGENTS.md`):**
  - When a measurement is missing (`nil`), `ConditionsGrid` renders `"—"` (`FrenchFormat` fallback). Because `"—"` has no digits, `.contentTransition(.numericText())` cleanly cross-fades to `"—"` and **never** animates through `0` (Invariant 3: *Never invent a value*).

---

### Opportunity 5 — Spot-to-Detail Zoom Navigation Transition + iOS 27 `CrossFadeNavigationTransition`

- **Status:** **VERIFIED IN SDK** (`SwiftUI.swiftinterface` lines 11279–11329, 19242–19247; `SwiftUICore.swiftinterface` lines 23765–23769)
- **Verbatim SDK declarations:**
  ```swift
  extension SwiftUICore.View {
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    nonisolated public func navigationTransition(_ style: some NavigationTransition) -> some SwiftUICore.View

    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    nonisolated public func matchedTransitionSource(id: some Hashable, in namespace: SwiftUICore.Namespace.ID) -> some SwiftUICore.View
  }

  @available(iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  @available(macOS, unavailable)
  extension SwiftUI.NavigationTransition where Self == SwiftUI.ZoomNavigationTransition {
    public static func zoom(sourceID: some Hashable, in namespace: SwiftUICore.Namespace.ID) -> SwiftUI.ZoomNavigationTransition
  }

  @available(iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
  @available(macOS, unavailable)
  extension SwiftUI.NavigationTransition where Self == SwiftUI.CrossFadeNavigationTransition {
    public static var crossFade: SwiftUI.CrossFadeNavigationTransition { get }
  }

  extension SwiftUICore::EnvironmentValues {
    @available(iOS 26.4, macOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *)
    public var accessibilityPrefersCrossFadeTransitions: Swift::Bool { get set }
  }
  ```
- **Target Estran screen(s):**
  - `Spots` (`Estran/Features/Spots/SpotsView.swift`) → `SpotDetail` (`Estran/Features/SpotDetail/SpotDetailView.swift`).
- **What it would look like:**
  - Today, tapping `"Voir le détail de la marée"` on `SpotsView` triggers `showDetail = true` and performs a standard horizontal push transition.
  - `ARCHITECTURE_PLAN.md` §12.5 #5 explicitly called for: *"Zoom navigation transition (`matchedTransitionSource` + `.navigationTransition(.zoom)`) — The spot card grows into the spot detail (tide chart); Reduce Motion → cross-fade"*.
  - With **iOS 27.0**, `CrossFadeNavigationTransition` (`.navigationTransition(.crossFade)`) is now a first-class built-in `NavigationTransition` alongside `.zoom(sourceID:in:)`!
  - By tagging the spot summary card in `SpotsView` with `.matchedTransitionSource(id: app.selectedSpot.id, in: zoomNamespace)` and applying:
    ```swift
    .navigationTransition(
        (reduceMotion || prefersCrossFade)
            ? AnyNavigationTransition(.crossFade) // or conditional ViewModifier
            : AnyNavigationTransition(.zoom(sourceID: app.selectedSpot.id, in: zoomNamespace))
    )
    ```
    (via a small `@ViewBuilder` branch on `SpotDetailView`), the glass spot card on the map fluidly expands into the full-screen `SpotDetailView` with interactive pinch/swipe-down dismissal back into the card on the map.
- **Accessibility implications:**
  - **Reduce Motion & `accessibilityPrefersCrossFadeTransitions`:** Directly honors both `@Environment(\.accessibilityReduceMotion)` and `@Environment(\.accessibilityPrefersCrossFadeTransitions)` by switching to the native iOS 27 `.navigationTransition(.crossFade)`.
  - **VoiceOver:** Standard Back button (`"Spots"`) in the navigation bar and two-finger Z-scrub dismissal remain completely intact.
- **Invariant check (`AGENTS.md`):**
  - Only the 2 validated spots (`Spot.allCases`: `Pointe de Grave`, `Arcachon — Jetée d'Eyrac`) exist as transition sources (Invariant 8: *Two spots*).

---

### Opportunity 6 — Scroll Edge Glass & Background Extension (`scrollEdgeEffectStyle`, `backgroundExtensionEffect`)

- **Status:** **VERIFIED IN SDK** (`SwiftUI.swiftinterface`, lines 15604–15609, 15679–15703)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  public struct ScrollEdgeEffectStyle : Swift.Hashable, Swift.Sendable {
    public static var automatic: SwiftUI.ScrollEdgeEffectStyle { get }
    public static var hard: SwiftUI.ScrollEdgeEffectStyle { get }
    public static var soft: SwiftUI.ScrollEdgeEffectStyle { get }
  }

  extension SwiftUICore.View {
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
    @available(visionOS, unavailable)
    nonisolated public func scrollEdgeEffectStyle(_ style: SwiftUI.ScrollEdgeEffectStyle?, for edges: SwiftUICore.Edge.Set) -> some SwiftUICore.View

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    @_Concurrency.MainActor @preconcurrency public func backgroundExtensionEffect() -> some SwiftUICore.View
  }
  ```
- **Target Estran screen(s):**
  - `Home` (`Estran/Features/Home/HomeView.swift`), `SpotDetail` (`Estran/Features/SpotDetail/SpotDetailView.swift`), `Spots` (`Estran/Features/Spots/SpotsView.swift`), `Alertes` (`Estran/Features/Alerts/AlertsView.swift`), `Réglages` (`Estran/Features/Settings/SettingsView.swift`).
- **What it would look like:**
  - `HomeView` hides the navigation bar (`.toolbar(.hidden, for: .navigationBar)`), so when the user scrolls down to read `ConditionsGrid`, `TipCard`, or the trust footer, glass cards pass directly under the Dynamic Island / status bar clock and above the floating Liquid Glass tab bar.
  - Applying `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])` on the `ScrollView` in `HomeView` and `SpotDetailView` activates the signature iOS 26/27 progressive variable-blur edge pocket at the status bar and floating tab bar boundaries, preventing white card text from colliding with the status bar clock or floating tab bar labels.
  - Applying `.backgroundExtensionEffect()` to the map canvas in `SpotsView` ensures the coastline rendering extends seamlessly beneath the top safe area and bottom floating tab bar with subtle peripheral blur.
- **Accessibility implications:**
  - **Reduce Transparency:** The system automatically converts `.scrollEdgeEffectStyle(.soft)` into an opaque material bar when `accessibilityReduceTransparency` is enabled.
  - **Dynamic Type AX5:** At `AX5`, `HomeView` and `SpotDetailView` require significant vertical scrolling; `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])` prevents large `AX5` typography from clashing with the system status bar.
- **Invariant check (`AGENTS.md`):**
  - Visual scroll container treatment only; no impact on domain or safety copy.

---

### Opportunity 7 — Modern `Tab` API + `.tabBarMinimizeBehavior(.onScrollDown)` + `.tabViewBottomAccessory` + iOS 27.1 `ToolbarVerticalCompressionBehavior.prefersTabBar`

- **Status:** **VERIFIED IN SDK** (`SwiftUI.swiftinterface`, lines 11344–11368, 17729–17741, 18584–18646, 25471–25490)
- **Verbatim SDK declarations:**
  ```swift
  extension SwiftUICore.View {
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    nonisolated public func tabBarMinimizeBehavior(_ behavior: SwiftUI.TabBarMinimizeBehavior) -> some SwiftUICore.View

    @available(iOS 26.1, *)
    @available(macOS, unavailable) @available(tvOS, unavailable) @available(watchOS, unavailable) @available(visionOS, unavailable)
    nonisolated public func tabViewBottomAccessory<Content>(isEnabled: Swift.Bool, @SwiftUICore.ContentBuilder content: () -> Content) -> some SwiftUICore.View where Content : SwiftUICore.View

    @available(anyAppleOS 27.1, *)
    nonisolated public func toolbarVerticalCompressionBehavior(_ behavior: SwiftUI.ToolbarVerticalCompressionBehavior) -> some SwiftUICore.View
  }

  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  public struct TabBarMinimizeBehavior : Swift.Hashable, Swift.Sendable {
    public static let automatic: SwiftUI.TabBarMinimizeBehavior
    @available(iOS 26.0, *) public static let onScrollDown: SwiftUI.TabBarMinimizeBehavior
    @available(iOS 26.0, *) public static let onScrollUp: SwiftUI.TabBarMinimizeBehavior
    @available(iOS 26.0, *) public static let never: SwiftUI.TabBarMinimizeBehavior
  }

  @available(anyAppleOS 27.1, *)
  public struct ToolbarVerticalCompressionBehavior : Swift.Hashable, Swift.Sendable {
    public static let automatic: SwiftUI.ToolbarVerticalCompressionBehavior
    public static let prefersToolbar: SwiftUI.ToolbarVerticalCompressionBehavior
    public static let prefersTabBar: SwiftUI.ToolbarVerticalCompressionBehavior
  }
  ```
- **Target Estran screen(s):**
  - `RootView` (`Estran/App/RootView.swift`) across all 4 tabs (`Aujourd'hui`, `Spots`, `Alertes`, `Réglages`).
- **What it would look like:**
  - Migrating `RootView.swift` from legacy `.tabItem { Label(...) }.tag(...)` to the declarative `Tab("Aujourd'hui", systemImage: "water.waves", value: AppModel.Tab.today) { ... }` syntax unlocks the full iOS 26/27 floating Liquid Glass tab bar behavior.
  - Adding `.tabBarMinimizeBehavior(.onScrollDown)` (`ARCHITECTURE_PLAN.md` §12.5 #6) causes the floating Liquid Glass tab pill to smoothly collapse into a compact icon bubble as the user scrolls down into `ConditionsGrid` or `ActivityOverviewList`, freeing vertical viewport height on iPhone 17/18 screens, and re-expand on scroll up.
  - Adding `.toolbarVerticalCompressionBehavior(.prefersTabBar)` (new in **iOS 27.1**) coordinates top toolbar and bottom tab bar compression in landscape / large Dynamic Type sizes.
  - *Optional enhancement:* `.tabViewBottomAccessory(isEnabled: ...)` can surface a compact live-session pill (`"Créneau en cours · fin 17h30"`) when a Live Activity is active, morphing seamlessly into the minimized tab bar when scrolling via `@Environment(\.tabViewBottomAccessoryPlacement)`.
- **Accessibility implications:**
  - **Reduce Motion:** When `@Environment(\.accessibilityReduceMotion)` is `true`, pass `.tabBarMinimizeBehavior(.never)` so the 4 tab targets never move or shrink under the user's thumb.
  - **Dynamic Type AX5:** Large-content viewer and VoiceOver tab bar traits work natively with `Tab(...)`.
- **Invariant check (`AGENTS.md`):**
  - If `.tabViewBottomAccessory` is used for an active session pill, it must never show for `.swimming` (since `LiveActivityController` already gates `guard decision.activity != .swimming, decision.status == .go`, Invariant 1 is preserved).

---

### Opportunity 8 — Concentric Corner Geometry (`ConcentricRectangle` / `.rect(corners: .concentric)` + `.containerShape`)

- **Status:** **VERIFIED IN SDK** (`SwiftUICore.swiftinterface`, lines 17260–17297, 17406–17409)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  public struct ConcentricRectangle : SwiftUICore::Shape, SwiftUICore::Animatable {
    public init(corners: SwiftUICore::Edge.SwiftUICore::Corner.SwiftUICore::Style, isUniform: Swift::Bool = false)
  }

  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  extension SwiftUICore::Shape where Self == SwiftUICore::ConcentricRectangle {
    @export(implementation) public static func rect(corners: SwiftUICore::Edge.SwiftUICore::Corner.SwiftUICore::Style, isUniform: Swift::Bool = false) -> Self
  }

  extension SwiftUICore::View {
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    @inlinable nonisolated public func containerShape(_ shape: some RoundedRectangularShape) -> some SwiftUICore::View
  }
  ```
- **Target Estran screen(s):**
  - `Estran/Theme/GlassStyles.swift` (`OceanGlassSurfaceModifier`), `Estran/Features/ActivityPicker/ActivityPickerView.swift` (icon wells nested inside glass rows), `Estran/Features/Home/Components/ConditionsGrid.swift` (icon wells inside condition tiles), and `EstranWidgets/GoWidget.swift` / `ConditionsWidget.swift`.
- **What it would look like:**
  - Right now, outer cards use a fixed `cornerRadius: 20` and nested elements (such as the `44×44` activity icon square with `cornerRadius: 12` inside `ActivityPickerView` rows with `16 pt` padding) use hard-coded radii that are not optically concentric (`20 - 16 = 4`, not `12`), creating uneven inner padding tracks.
  - Declaring `.containerShape(RoundedRectangle(cornerRadius: 20, style: .continuous))` in `OceanGlassSurfaceModifier` and using `.rect(corners: .concentric(minimum: 10), isUniform: true)` on nested icon wells, inner callout banners, and widget sub-tiles makes every inner curve mathematically concentric with its parent glass card or the iPhone 17/18 display bezel / widget container.
- **Accessibility implications:**
  - **Dynamic Type AX5:** As `@ScaledMetric` grows nested icon wells from `44 pt` to `64+ pt`, concentric corners automatically recalculate curvature relative to container padding, avoiding awkward pill/square distortion.
- **Invariant check (`AGENTS.md`):**
  - Purely geometric refinement; zero impact on data or copy.

---

### Opportunity 9 — iOS 27 Dynamic Island Width Adaptation (`\.isDynamicIslandLimitedInWidth`) + Widget `\.levelOfDetail` & `.supportedMountingStyles`

- **Status:** **VERIFIED IN SDK** (`WidgetKit.swiftinterface`, lines 122–134, 244–261, 615–622, 1650–1656)
- **Verbatim SDK declarations:**
  ```swift
  extension SwiftUICore::EnvironmentValues {
    @available(iOS 27.0, *)
    @available(macOS, unavailable) @available(tvOS, unavailable) @available(watchOS, unavailable) @available(visionOS, unavailable)
    public var isDynamicIslandLimitedInWidth: Swift::Bool { get }

    @available(iOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable) @available(macOS, unavailable) @available(watchOS, unavailable)
    public var levelOfDetail: WidgetKit::LevelOfDetail { get set }
  }

  @available(iOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable) @available(macOS, unavailable) @available(watchOS, unavailable)
  public struct LevelOfDetail : Swift::Hashable, Swift::Sendable {
    public static let `default`: WidgetKit::LevelOfDetail
    public static let simplified: WidgetKit::LevelOfDetail
  }

  @available(iOS 26.0, visionOS 26.0, *)
  @available(macOS, unavailable) @available(watchOS, unavailable) @available(tvOS, unavailable)
  extension SwiftUI::WidgetConfiguration {
    @_Concurrency::MainActor @preconcurrency public func supportedMountingStyles(_ styles: [WidgetKit::WidgetMountingStyle]) -> some SwiftUI::WidgetConfiguration
  }
  ```
- **Target Estran screen(s):**
  - Live Activity: `EstranWidgets/LiveActivity/GoLiveActivityView.swift`.
  - Widgets: `EstranWidgets/GoWidget.swift`, `EstranWidgets/ConditionsWidget.swift`.
- **What it would look like:**
  - In `EstranWidgets/LiveActivity/GoLiveActivityView.swift` (line 45), `compactLeading` currently hard-codes a single letter `"O"` / `"N"` with the comment: `// The letter is a width compromise; the accessibility label spells out the full French verdict`.
  - **New in iOS 27.0**, WidgetKit provides `@Environment(\.isDynamicIslandLimitedInWidth)`. When `isDynamicIslandLimitedInWidth == false` (single activity in the Dynamic Island on iPhone 17/18 with plenty of horizontal space), `compactLeading` can render the full French word **`"Oui"`** / **`"Non"`** (with the colored dot), and automatically compact down to `"O"` / `"N"` only when `isDynamicIslandLimitedInWidth == true`!
  - In `GoWidget` and `ConditionsWidget`, reading `@Environment(\.levelOfDetail)` lets the widgets simplify secondary labels (`"Prochain créneau"`, `"Modèle local"`) when `levelOfDetail == .simplified` (StandBy distance view / Always-On dimmed state), keeping the primary verdict (`Oui` / `Attention` / `Non`), tide arrow (`↑ 3,1 m`), and wind (`15 nds`) bold and legible across a room.Adding `.supportedMountingStyles([.flat, .elevated])` opts the widgets into spatial/StandBy glass depth.
- **Accessibility implications:**
  - **VoiceOver:** Keep `.accessibilityLabel(context.state.isGo ? "Oui" : "Non")` on `compactLeading` regardless of whether `"Oui"` or `"O"` is visually drawn.
  - **Dynamic Type & Luminance:** `levelOfDetail == .simplified` increases glanceability by hiding low-priority tertiary text in Always-On / StandBy modes.
- **Invariant check (`AGENTS.md`):**
  - **Invariant 1 (No `Oui` for swimming):** `LiveActivityController.start` already rejects `.swimming` (`guard decision.activity != .swimming`), and `GoWidget` routes `.swimming` through `swimmingSmall` / `swimmingRow` (which render `swimmingRisk.displayName` + `"Courants de baïnes"`, never `Oui`). A defence-in-depth check in `GoLiveActivityView` (`if context.attributes.activityName == Activity.swimming.displayName`) should also refuse to render `"Oui"`.
  - **Invariant 3 (Never invent a value):** `ConditionsWidget` continues to render `"—"` when a snapshot field is `nil`.

---

### Opportunity 10 — Foundation Models `@Generable` / `@Guide` Constrained Decoding & iOS 27 `DynamicProfile` + `prewarm`

- **Status:** **VERIFIED IN SDK** (`FoundationModels.swiftinterface`, lines 311, 820–844, 1138–1146, 2234–2250)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable) @available(watchOS, unavailable)
  @attached(extension, conformances: FoundationModels::Generable, names: named(init(_:)), named(generatedContent)) @attached(member, names: arbitrary)
  public macro Generable(description: Swift::String? = nil)

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  @attached(extension, conformances: FoundationModels::Generable, names: named(init(_:)), named(generatedContent)) @attached(member, names: arbitrary)
  public macro Generable(name: Swift::String, description: Swift::String? = nil, representNilExplicitlyInGeneratedContent: Swift::Bool = false)

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension FoundationModels::LanguageModelSession {
    final public func prewarm(promptPrefix: FoundationModels::Prompt? = nil)

    @discardableResult
    @_disfavoredOverload nonisolated(nonsending) final public func respond<Content>(to prompt: Swift::String, generating type: Content.Type = Content.self, options: FoundationModels::GenerationOptions = GenerationOptions(), contextOptions: FoundationModels::ContextOptions = ContextOptions(includeSchemaInPrompt: true), metadata: [Swift::String : any FoundationModels::ConvertibleToGeneratedContent] = [:]) async throws -> FoundationModels::LanguageModelSession.FoundationModels::Response<Content> where Content : FoundationModels::Generable

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    public struct DynamicProfile : Swift::Sendable {
      public init(isPrewarmed: Swift::Bool = true, LoadingDuration: FoundationModels::LanguageModelSession.FoundationModels::DynamicProfile.FoundationModels::LoadingDuration = .default)
    }
  }
  ```
- **Target Estran screen(s):**
  - `Home`: `AnswerCard` (`Estran/Features/Home/Components/AnswerCard.swift`) and `TipCard` (`Estran/Features/Home/Components/TipCard.swift`) via `Estran/Reason/FoundationModelReasonProvider.swift`.
- **What it would look like:**
  - Today, `TipCard.swift` contains a static `switch activity` comment: `// Until M4 (Foundation Models), this is a template`, while `FoundationModelReasonProvider.swift` asks `LanguageModelSession` for an unconstrained `String` (`session.respond(to: prompt, options: ...)`).
  - By defining an on-device `@Generable` struct:
    ```swift
    @Generable(name: "ExplicationEstran", description: "Explication courte et conseil de sortie en français (tutoiement).")
    struct GeneratedBriefing: Sendable {
        @Guide(description: "Une phrase courte expliquant le verdict, uniquement avec les chiffres fournis.")
        var reason: String
        @Guide(description: "Un conseil pratique en tutoiement (1 phrase, moins de 90 caractères).")
        var tip: String
    }
    ```
    and calling `session.prewarm(promptPrefix:)` when `HomeView` appears, a single on-device pass generates both the `AnswerCard` explanation and a contextual `TipCard` (e.g., *"Profite du jusant pour prospecter le bord du banc avant l'étale."*), while passing both fields through `FoundationModelReasonProvider.isAcceptable(_:decision:)` and falling back deterministically if rejected.
- **Accessibility implications:**
  - Keeps generated strings under 90 characters (`@Guide`) so `AX5` Dynamic Type cards do not balloon vertically.
  - When the model generates asynchronously after initial render, apply `.contentTransition(.opacity)` (or instant swap under `accessibilityReduceMotion`) so the deterministic template does not jump jar-like.
- **Invariant check (`AGENTS.md`):**
  - **Invariant 1 (No `Oui` for swimming):** `FoundationModelReasonProvider` already skips `.swimming` (`if decision.activity == .swimming { return decision.reason }`) and `isAcceptable` rejects `"oui"`, `"favorable"`, `"recommand"`, `"baignade sûre"`.
  - **Invariant 2 (Never claim officiality):** `isAcceptable` rejects `"shom"`, `"officiel"`, `"certifié"`, `"mesure locale"`, `"bouée"`.
  - **Invariant 3 (Never invent a value):** `isAcceptable` verifies every digit sequence in the generated text appears in the input prompt (`promptNumbers.isSuperset(of: outputNumbers)`).
  - **Invariant 7 (On-device only):** Must use `SystemLanguageModel.default` only — **never** `PrivateCloudComputeLanguageModel` (see §2.13 below).

---

### Opportunity 11 — iOS 27 Scene Accessories (`sceneAccessory`, `ExternalNonInteractiveAccessory`)

- **Status:** **VERIFIED IN SDK** (`SwiftUI.swiftinterface`, lines 19929–19937, 20906–20925)
- **Verbatim SDK declarations:**
  ```swift
  @available(iOS 27.0, *)
  @available(macCatalyst, unavailable) @available(macOS, unavailable) @available(tvOS, unavailable) @available(watchOS, unavailable) @available(visionOS, unavailable)
  extension SwiftUICore.View {
    nonisolated public func sceneAccessory<C>(@SwiftUICore.ContentBuilder content: () -> C) -> some SwiftUICore.View where C : SwiftUI.SceneAccessoryContent
  }

  @available(iOS 27.0, *)
  @available(macCatalyst, unavailable) @available(macOS, unavailable) @available(tvOS, unavailable) @available(watchOS, unavailable) @available(visionOS, unavailable)
  nonisolated public struct ExternalNonInteractiveAccessory<Content> : SwiftUI.SceneAccessoryContent where Content : SwiftUICore.View {
    nonisolated public init(@SwiftUICore.ContentBuilder content: @escaping () -> Content)
    nonisolated public init(isEnabled: SwiftUICore.Binding<Swift.Bool>, @SwiftUICore.ContentBuilder content: @escaping () -> Content)
  }
  ```
- **Target Estran screen(s):**
  - `RootView` (`Estran/App/RootView.swift`) / `EstranApp` (`Estran/App/EstranApp.swift`).
- **What it would look like:**
  - Exclusive to **iOS 27.0 on iPhone**, `.sceneAccessory { ExternalNonInteractiveAccessory { ... } }` renders a compact, non-interactive glanceable view for external iPhone cover/stand accessory cutouts.
  - Estran can project a minimal 1-line marine badge:
    - For `Surf` / `Kite` / `Kayak` / `Pêche`: colored status dot + `"Surf · Oui · ↑ 2,8 m"` (or `"Surf · Données indisponibles"`).
    - For `Baignade`: amber warning triangle + `"Baignade · Risque modéré · Baïnes"`.
- **Accessibility implications:**
  - `ExternalNonInteractiveAccessory` is non-interactive by design; combine child elements into a single `.accessibilityElement(children: .combine)` summary string and use `OceanPalette` high-contrast foreground tokens.
- **Invariant check (`AGENTS.md`):**
  - **Invariant 1:** Must branch on `app.selectedActivity == .swimming` so the scene accessory **never** displays `Oui` for swimming (`"Risque faible / modéré / élevé · Baïnes"` or `"Données indisponibles"` only).
  - **Invariant 4:** When `forecast == nil` or status is `.unavailable`, render `"Données indisponibles"`.

---

### Opportunity 12 — iOS 27 Spotlight `IndexedEntityQuery` + `@ComputedProperty(indexingKey:)` + `TargetContentProvidingIntent`

- **Status:** **VERIFIED IN SDK** (`AppIntents.swiftinterface`, lines 7798–7816, 8078–8088, 8367–8371)
- **Verbatim SDK declarations:**
  ```swift
  @available(macOS 27.0, iOS 27.0, visionOS 27.0, *)
  public protocol IndexedEntityQuery : AppIntents::EntityQuery where Self.Entity : AppIntents::IndexedEntity {
    func reindexEntities(for identifiers: [Self.Entity.ID], indexDescription: CoreSpotlight::CSSearchableIndexDescription) async throws
    func reindexAllEntities(indexDescription: CoreSpotlight::CSSearchableIndexDescription) async throws
  }

  @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
  public protocol TargetContentProvidingIntent : AppIntents::AppIntent {
  }
  ```
- **Target Estran screen(s):**
  - `Siri / Shortcuts / Spotlight` (`Estran/Intents/EstranIntents.swift`) → deep-linking into `HomeView` or `SpotDetailView`.
- **What it would look like:**
  - Today, `EstranIntents.swift` defines `SpotChoice` and `ActivityChoice` as `AppEnum`s and `OpenEstranIntent` with `openAppWhenRun = true`, but `OpenEstranIntent.perform()` does not pass the chosen `SpotChoice` into `AppModel.selectedSpot`, nor are the two spots indexed in Spotlight.
  - Adopting `IndexedEntity` + **iOS 27.0** `IndexedEntityQuery` for the two spots (`Pointe de Grave`, `Arcachon — Jetée d'Eyrac`) and conforming `OpenEstranIntent` to `TargetContentProvidingIntent` allows a user typing *"Arcachon marée"* or *"Pointe de Grave surf"* in iPhone Spotlight to see a rich Estran spot card and jump straight to that spot in `HomeView`.
- **Accessibility implications:**
  - Provides zero-navigation voice and Spotlight access for motor-impaired and VoiceOver users.
- **Invariant check (`AGENTS.md`):**
  - **Invariant 1:** `AnswerIntent.spoken(from:)` in `EstranIntents.swift` already formats `.swimming` as `"À \(spot.displayName), la baignade présente un \(risk). \(reason) Attention aux baïnes et aux courants."` — keep that exact spoken guard for any Spotlight/Siri entity summary.
  - **Invariant 8:** `reindexAllEntities` indexes **only** `Spot.allCases` (2 spots).

---

### 2.13 SDK APIs Inspected and Deliberately Excluded (Invariant / UX Gate)

During the `.swiftinterface` inspection of `iPhoneOS27.2.sdk`, two prominent new APIs were verified in the SDK but **must not** be used in Estran:

1. **`FoundationModels.PrivateCloudComputeLanguageModel` (`@available(iOS 27.0, *)`) — VERIFIED IN SDK (`FoundationModels.swiftinterface` L44), EXCLUDED:**
   - *Why excluded:* Estran's product definition (`AGENTS.md` §"The product": *"on-device, free, no account, no backend"*) and `ARCHITECTURE_PLAN.md` forbid sending user activity/location context off-device to cloud compute. Only `SystemLanguageModel.default` (100% on-device) is permitted.
2. **`Charts.Chart3D` / `SurfacePlot` (`@available(iOS 26.0, *)`) — VERIFIED IN SDK (`Charts.swiftinterface` L4149), EXCLUDED:**
   - *Why excluded:* `TideChartCard` is a safety-critical 2D height-over-time curve with feasible time windows (`RectangleMark`), a `"Maintenant"` `RuleMark`, and `AXChartDescriptorRepresentable` + `.accessibilityRepresentation` for VoiceOver and `AX5`. A 3D perspective chart degrades height reading accuracy and breaks 2D scrub legibility.

---

## 3. Proposed First Slice (3–4 Items for Maximum "Wow" at Lowest Risk)

This first slice delivers the biggest visual transformation on iPhone 17/18 (iOS 27) while touching **only** view/theme files in `Estran/` and `EstranWidgets/`, requiring zero schema changes, zero new targets, and zero domain changes in `EstranCore`.

### Slice Item 1 — Living `MeshGradient` Ocean Backdrop + `.scrollEdgeEffectStyle(.soft)`
- **Why first:** Liquid Glass (`OceanGlassSurfaceModifier`) can only refract what is behind it. Replacing the flat 2-stop `LinearGradient` with the slow 3×3 `MeshGradient` (deep navy + turquoise `#30D5C8` + blue glow `#0091FF`, paused when `accessibilityReduceMotion` is on or scene is inactive) and adding `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])` immediately transforms the visual depth of `HomeView` and `SpotDetailView`.
- **APIs used:** `MeshGradient`, `Color.headroom(_:)`, `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])`, `.backgroundExtensionEffect()`.
- **Files touched:**
  - `Estran/Theme/OceanPalette.swift` (add `OceanBackdropView` with `MeshGradient` + `@Environment(\.accessibilityReduceMotion)` + `@Environment(\.scenePhase)` guards)
  - `Estran/Features/Home/HomeView.swift` (mount `OceanBackdropView()` and `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])`)
  - `Estran/Features/SpotDetail/SpotDetailView.swift` (mount `OceanBackdropView()` and `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])`)
  - `Estran/Features/Spots/SpotsView.swift` (add `.backgroundExtensionEffect()` on the map layer)

### Slice Item 2 — Interactive & Morphing Liquid Glass (`Glass.interactive()`, `glassEffectID`, `glassEffectTransition`, `glassEffectUnion`)
- **Why second:** Turns the static glass pills in `ActivitySegmentedControl` and `SpotSwitcher` into authentic iOS 26/27 Liquid Glass controls that deflect light under the thumb (`.interactive()`), fuse into a single translucent track (`glassEffectUnion`), and fluidly stretch the white selection droplet from activity to activity (`glassEffectID` + `glassEffectTransition(.matchedGeometry())`, falling back to `.identity` under `accessibilityReduceMotion`).
- **APIs used:** `Glass.interactive(_:)`, `.glassEffectID(_:in:)`, `.glassEffectTransition(_:)`, `.glassEffectUnion(id:namespace:)`, `@Environment(\.accessibilityReduceMotion)`, `@Environment(\.accessibilityPrefersCrossFadeTransitions)`.
- **Files touched:**
  - `Estran/Features/Home/Components/ActivitySegmentedControl.swift`
  - `Estran/Features/Spots/SpotSwitcher.swift`
  - `Estran/Features/Home/HomeView.swift` (morph transition between `AnswerCard` and `SwimmingAdvisoryCard` inside `GlassEffectContainer`)
  - `Estran/Features/ActivityPicker/ActivityPickerView.swift` (add `.interactive()` to top bar glass circle buttons)

### Slice Item 3 — Verdict Motion, Numeric Rolling, Scroll Choreography & Selection Haptics
- **Why third:** Completes the remaining unchecked items in `ARCHITECTURE_PLAN.md` §12.5 (`symbolEffect`, `contentTransition(.numericText())`, `scrollTransition`, `sensoryFeedback(.selection)`) so every activity switch or tide chart scrub feels responsive, tactile, and alive.
- **APIs used:** `.symbolEffect(.bounce, value:)`, `.contentTransition(.symbolEffect(.replace))`, `.contentTransition(.numericText())`, `.scrollTransition(_:axis:transition:)`, `.sensoryFeedback(.selection, trigger:)`.
- **Files touched:**
  - `Estran/Features/Home/Components/AnswerCard.swift`
  - `Estran/Features/Home/Components/SwimmingAdvisoryCard.swift`
  - `Estran/Features/Home/Components/ConditionsGrid.swift`
  - `Estran/Features/Home/HomeView.swift`
  - `Estran/Features/SpotDetail/SpotDetailView.swift`
  - `Estran/Features/SpotDetail/TideChartCard.swift`

### Slice Item 4 — Spot-to-Detail Zoom Transition (with iOS 27 `.crossFade` Fallback), Minimizing Tab Bar & Dynamic Island Width Adaptation
- **Why fourth:** Connects `SpotsView` and `SpotDetailView` with the zoom transition (`matchedTransitionSource` + `.navigationTransition(.zoom)` / iOS 27 `.navigationTransition(.crossFade)` under Reduce Motion), upgrades `RootView` to `.tabBarMinimizeBehavior(.onScrollDown)` + iOS 27.1 `.toolbarVerticalCompressionBehavior(.prefersTabBar)`, and upgrades `GoLiveActivityView` with iOS 27's `@Environment(\.isDynamicIslandLimitedInWidth)` so the Dynamic Island shows `"Oui"` / `"Non"` whenever width allows.
- **APIs used:** `.matchedTransitionSource(id:in:)`, `.navigationTransition(.zoom(sourceID:in:))`, `.navigationTransition(.crossFade)` (iOS 27.0), `Tab`, `.tabBarMinimizeBehavior(.onScrollDown)`, `.toolbarVerticalCompressionBehavior(.prefersTabBar)` (iOS 27.1), `\.isDynamicIslandLimitedInWidth` (iOS 27.0).
- **Files touched:**
  - `Estran/App/RootView.swift`
  - `Estran/Features/Spots/SpotsView.swift`
  - `Estran/Features/SpotDetail/SpotDetailView.swift`
  - `EstranWidgets/LiveActivity/GoLiveActivityView.swift`
