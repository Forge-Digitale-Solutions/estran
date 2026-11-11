import SwiftUI
import WidgetKit

/// Widget bundle for Estran (M5):
/// - `GoWidget`: Home Screen (`systemSmall`, `systemMedium`, `systemLarge`) and
///   Lock Screen (`accessoryRectangular`, `accessoryCircular`, `accessoryInline`)
/// - `ConditionsWidget`: Home Screen 4-metric conditions card (`systemMedium`)
/// - `GoLiveActivityWidget`: Lock Screen and Dynamic Island Live Activity
/// - `EstranControl`: Control Center launcher
@main
struct EstranWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GoWidget()
        ConditionsWidget()
        GoLiveActivityWidget()
        EstranControl()
    }
}
