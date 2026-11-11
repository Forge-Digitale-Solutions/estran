import EstranCore
import SwiftUI
import UIKit
import UserNotifications

/// 04 — Alertes. Opt-in notification, one hour before a good window.
///
/// The toggle is persisted in the App Group so the widget and the notification
/// scheduler read the same preference. The permission is requested only when the
/// user opts in, and a refusal is shown, not swallowed.
struct AlertsView: View {
    @AppStorage("alertsEnabled", store: UserDefaults(suiteName: EstranAppGroup.identifier))
    private var alertsEnabled = false

    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL

    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OceanSpacing.lg) {
                    header
                    alertCard
                    if permissionDenied {
                        deniedCard
                    }
                    footnote
                }
                .padding(.horizontal, OceanSpacing.md)
                .padding(.top, OceanSpacing.sm)
                .padding(.bottom, OceanSpacing.xxl)
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .background { OceanBackdrop() }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshAuthorizationStatus() }
        }
    }

    /// The system prompt only runs when the toggle is turned on. A revocation
    /// between two launches leaves the toggle ON with no warning unless the
    /// current status is read on appear (early M3 review, point 8).
    @MainActor
    private func refreshAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                alertsEnabled = false
                permissionDenied = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
            Text("Alertes")
                .font(OceanTypography.largeTitle)
                .foregroundStyle(OceanPalette.white)
            Text("Sois prévenu une heure avant un bon créneau à \(app.selectedSpot.name).")
                .font(OceanTypography.subtitle)
                .foregroundStyle(OceanPalette.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var alertCard: some View {
        AlertOptInToggle { permissionDenied = true }
            .padding(OceanSpacing.md)
            .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.sm) {
            Label("Notifications désactivées", systemImage: "bell.slash")
                .font(OceanTypography.bodyEmphasized)
                .foregroundStyle(OceanPalette.unavailable)
            Text("Autorise les notifications dans Réglages pour recevoir les créneaux.")
                .font(OceanTypography.caption)
                .foregroundStyle(OceanPalette.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir les réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(OceanTypography.button)
            .foregroundStyle(OceanPalette.turquoiseOnGlass)
            .frame(minHeight: OceanGlass.minimumTapHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(OceanSpacing.md)
        .oceanGlassCard(cornerRadius: OceanGlass.cardCornerRadius)
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: OceanSpacing.xs) {
            Text("Les alertes sont une aide à la décision. Elles ne remplacent pas les documents officiels.")
                .fixedSize(horizontal: false, vertical: true)
            // M4 dependency, stated instead of hiding a dead toggle: the
            // preference is stored now, the scheduling lands with the live
            // weather pipeline.
            Text("La programmation des notifications sera active avec les données météo temps réel.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(OceanTypography.smallLabel)
        .foregroundStyle(OceanPalette.white.opacity(0.6))
    }
}

#Preview {
    AlertsPreview()
}

private struct AlertsPreview: View {
    @State private var app = AppModel()

    var body: some View {
        AlertsView()
            .environment(app)
            .task { await app.reload() }
    }
}
