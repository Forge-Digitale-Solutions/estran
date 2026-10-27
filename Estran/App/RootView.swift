import SwiftUI

/// Tab shell. Owns the single `AppModel` and loads the forecast once.
struct RootView: View {
    @State private var app = AppModel()

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
    }
}

#Preview {
    RootView()
}
