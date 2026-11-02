import EstranCore
import SwiftUI

/// Tab shell. Owns the single `AppModel` and loads the forecast once.
struct RootView: View {
    @State private var app = AppModel()
    @State private var showsActivityPicker = false

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
            HomeView()
                .tabItem { Label(AppTab.now.title, systemImage: AppTab.now.symbolName) }
                .tag(AppTab.now)

            SpotsView()
                .tabItem { Label(AppTab.spots.title, systemImage: AppTab.spots.symbolName) }
                .tag(AppTab.spots)

            AlertsView()
                .tabItem { Label(AppTab.alerts.title, systemImage: AppTab.alerts.symbolName) }
                .tag(AppTab.alerts)

            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbolName) }
                .tag(AppTab.settings)
        }
        .environment(app)
        .tint(OceanPalette.turquoise)
        .preferredColorScheme(.dark)
        .task {
            await app.reload()
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

#Preview {
    RootView()
}
