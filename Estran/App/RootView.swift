import EstranCore
import SwiftUI

/// Tab shell. Owns the single `AppModel` and loads the forecast once.
struct RootView: View {
    @State private var app = AppModel()
    @State private var showsActivityPicker = false
    @State private var showsScreenshotDetail = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// First launch only: the activity picker introduces the five activities
    /// (Figma frame 03). Dismissing it without choosing is allowed — the Home
    /// default is a real activity, not an empty state — so the flag is written
    /// as soon as the sheet is presented.
    @AppStorage("hasChosenActivity", store: UserDefaults(suiteName: EstranAppGroup.identifier))
    private var hasChosenActivity = false

    var body: some View {
        TabView(
            selection: Binding(
                get: { app.selectedTab },
                set: { app.select(tab: $0) }))
        {
            Tab(AppTab.now.title, systemImage: AppTab.now.symbolName, value: AppTab.now) {
                HomeView()
            }
            Tab(AppTab.spots.title, systemImage: AppTab.spots.symbolName, value: AppTab.spots) {
                SpotsView()
            }
            Tab(AppTab.alerts.title, systemImage: AppTab.alerts.symbolName, value: AppTab.alerts) {
                AlertsView()
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbolName, value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(reduceMotion ? .never : .onScrollDown)
        .modifier(PrefersTabBarCompressionModifier())
        .environment(app)
        .tint(OceanPalette.turquoise)
        .preferredColorScheme(.dark)
        .task {
            await app.reload()
            // A cold launch from a Spotlight hit: the spot was already read by
            // `AppModel.init`, the activity was not.
            await app.applyIntentSelectionIfNeeded()
            applyScreenshotLaunchArguments()
        }
        // A warm launch: an `OpenIntent` runs in this process while the app is
        // in the background, so the App Group write only lands here, on the way
        // back to the foreground. The same activation re-warms the on-device
        // session, which the system may have evicted while backgrounded (no-op
        // without Apple Intelligence).
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await app.applyIntentSelectionIfNeeded()
                app.prewarmReasonSession()
            }
        }
        // `onChange` rather than the line after `await app.reload()`: the picker
        // needs the loaded overviews, and a phase change is the reliable signal
        // that they exist (a cancelled task never reaches its next statement).
        .onChange(of: app.store.phase, initial: true) { _, _ in
            presentActivityPickerIfNeeded()
        }
        .fullScreenCover(isPresented: $showsActivityPicker) {
            ActivityPickerView(
                spotName: app.selectedSpot.name,
                overviews: app.overviews,
                selection: app.activity,
                timeZone: app.selectedSpot.timezone,
                onSelect: { app.select(activity: $0) })
        }
        .fullScreenCover(isPresented: $showsScreenshotDetail) {
            NavigationStack {
                SpotDetailView()
            }
            .environment(app)
            .preferredColorScheme(.dark)
        }
        // A widget tap carries a spot + activity deep link; the URL scheme is
        // the same one the widget builds, so the app opens exactly the place the
        // widget was showing.
        .onOpenURL { url in
            guard let target = WidgetDeepLink.parse(url) else { return }
            Task {
                await app.openWidget(spotID: target.spotID, activity: target.activity)
            }
        }
    }

    /// Simulator screenshot helpers (`-estranTab`, `-estranOpenDetail`). No-ops
    /// in normal launches; the integrator's UI tests do not depend on them.
    private func applyScreenshotLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-estranTab"), args.index(after: index) < args.endIndex {
            switch args[args.index(after: index)] {
            case "spots": app.select(tab: .spots)
            case "alerts": app.select(tab: .alerts)
            case "settings": app.select(tab: .settings)
            default: break
            }
        }
        if args.contains("-estranOpenDetail") {
            showsScreenshotDetail = true
        }
    }

    /// One shot, first launch only, once the answers exist. Dismissing without
    /// choosing is allowed: the default activity is a real one, not an empty
    /// state.
    private func presentActivityPickerIfNeeded() {
        guard !hasChosenActivity, !app.overviews.isEmpty, !showsActivityPicker else { return }
        hasChosenActivity = true
        showsActivityPicker = true
    }
}

/// iOS 27.1 coordinates top toolbar and bottom tab bar compression. Deployment
/// is 27.0, so the call is gated; skip silently on 27.0 runtimes.
private struct PrefersTabBarCompressionModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if ESTRAN_SDK_BEFORE_27
            content
        #else
            if #available(iOS 27.1, *) {
                content.toolbarVerticalCompressionBehavior(.prefersTabBar)
            } else {
                content
            }
        #endif
    }
}

#Preview {
    RootView()
}
