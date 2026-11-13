import EstranCore
import SwiftUI
import WidgetKit

// The five families at a glance, for the Xcode canvas.
//
// Kept out of `GoWidget.swift` so the widget's configuration file stays
// small enough to read in one screen; nothing here ships in the widget.

#Preview("Small", as: .systemSmall) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    GoWidget()
} timeline: {
    GoEntry.sampleNoGo
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Circular", as: .accessoryCircular) {
    GoWidget()
} timeline: {
    GoEntry.sample
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    GoWidget()
} timeline: {
    GoEntry.sampleNoGo
    GoEntry.sampleSwimming
    GoEntry.sampleStale
    GoEntry.placeholder
}
