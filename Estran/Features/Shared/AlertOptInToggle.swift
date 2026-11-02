import EstranCore
import SwiftUI
import UserNotifications

/// « Me prévenir 1 h avant » — the notification opt-in, shared by Alertes and
/// the spot detail.
///
/// One App Group key, one permission request: two screens that both store
/// `alertsEnabled` by hand would drift the moment one of them changes the key.
struct AlertOptInToggle: View {
    /// Called when the system refuses the permission; the screen decides how to
    /// say so (the Alertes screen has a dedicated card).
    var onDenied: () -> Void = {}

    @AppStorage("alertsEnabled", store: UserDefaults(suiteName: EstranAppGroup.identifier))
    private var alertsEnabled = false

    var body: some View {
        Toggle(isOn: $alertsEnabled) {
            VStack(alignment: .leading, spacing: OceanSpacing.xxs) {
                Text("Me prévenir 1 h avant")
                    .font(OceanTypography.bodyEmphasized)
                    .foregroundStyle(OceanPalette.white)
                Text("Une notification par créneau, jamais la nuit.")
                    .font(OceanTypography.smallLabel)
                    .foregroundStyle(OceanPalette.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(OceanPalette.turquoise)
        .onChange(of: alertsEnabled) { _, enabled in
            guard enabled else { return }
            requestAuthorization()
        }
    }

    /// The system prompt only runs on opt-in. A refusal puts the toggle back:
    /// a stored `true` with no permission would be a lie the next launch reads.
    @MainActor
    private func requestAuthorization() {
        Task {
            let granted = await (try? UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])) ?? false
            if !granted {
                alertsEnabled = false
                onDenied()
            }
        }
    }
}
